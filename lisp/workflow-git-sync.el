;;; workflow-git-sync.el --- Auto-sync workflow org git repo  -*- lexical-binding: t; -*-
;;
;; This file defines a global minor mode that watches `workflow-org-directory'
;; and performs a debounced asynchronous git sync pipeline.

(require 'cl-lib)
(require 'filenotify nil t)
(require 'org-core)
(require 'subr-x)

(defgroup workflow-git-sync nil
  "Automatically sync workflow Org repository with its git remote."
  :group 'workflow)

(defcustom workflow-git-sync-debounce-seconds 3
  "Seconds to wait after a filesystem event before syncing."
  :type 'number
  :group 'workflow-git-sync)

(defcustom workflow-git-sync-enabled t
  "When non-nil, enable automatic git sync for `workflow-org-directory'."
  :type 'boolean
  :group 'workflow-git-sync)

(defcustom workflow-git-sync-auto-pull-enabled t
  "When non-nil, periodically run a full upstream reconciliation sync."
  :type 'boolean
  :group 'workflow-git-sync)

(defcustom workflow-git-sync-pull-interval-seconds 30
  "Seconds between automatic upstream reconciliation checks."
  :type 'number
  :group 'workflow-git-sync)

(defcustom workflow-git-sync-exit-flush-enabled t
  "When non-nil, attempt one final sync when Emacs exits."
  :type 'boolean
  :group 'workflow-git-sync)

(defcustom workflow-git-sync-exit-flush-timeout-seconds 5
  "Maximum seconds to spend on final sync during Emacs exit."
  :type 'number
  :group 'workflow-git-sync)

(defvar workflow-git-sync--debounce-timer nil)
(defvar workflow-git-sync--pull-timer nil)
(defvar workflow-git-sync-mode)
(defvar workflow-git-sync--in-progress nil)
(defvar workflow-git-sync--pending nil)
(defvar workflow-git-sync--suppress-file-events nil)
(defvar workflow-git-sync--watch-descriptors nil)
(defvar workflow-git-sync--process nil)
(defvar workflow-git-sync--log-buffer " *workflow-git-sync*")
(defvar workflow-git-sync--refresh-buffers-after-rebase nil)

(defun workflow-git-sync--sync-org-roam-db ()
  "Sync org-roam DB."
  (condition-case err
      (org-roam-db-sync)
    (error
     (message "Workflow git sync: org-roam db sync failed: %s"
              (error-message-string err)))))

(defun workflow-git-sync--commit-message ()
  "Return autosync commit message with timestamp."
  (format "workflow autosync: %s"
          (format-time-string "%Y-%m-%d %H:%M:%S")))

(defun workflow-git-sync--file-notify-available-p ()
  "Return non-nil when file notifications are supported."
  (and (fboundp 'file-notify-supported-p)
       (file-notify-supported-p)))

(defun workflow-git-sync--org-root ()
  "Return normalized absolute path for `workflow-org-directory'."
  (file-name-as-directory (expand-file-name workflow-org-directory)))

(defun workflow-git-sync--git-error (fmt &rest args)
  "Display a minibuffer sync error using FMT and ARGS."
  (apply #'message (concat "Workflow git sync failed: " fmt) args))

(defun workflow-git-sync--path-in-org-p (path)
  "Return non-nil when PATH is inside `workflow-org-directory'."
  (when path
    (let ((expanded (expand-file-name path))
          (root (workflow-git-sync--org-root)))
      (string-prefix-p root expanded))))

(defun workflow-git-sync--git-path-p (path)
  "Return non-nil when PATH points to `.git' internals."
  (when path
    (or (string-match-p (rx "/.git" (or "/" eos)) (expand-file-name path))
        (string= (file-name-nondirectory (directory-file-name path)) ".git"))))

(defun workflow-git-sync--schedule (&optional immediate)
  "Schedule a sync run.
When IMMEDIATE is non-nil, bypass debounce and run now."
  (when workflow-git-sync-mode
    (if immediate
        (if workflow-git-sync--in-progress
            (setq workflow-git-sync--pending t)
          (workflow-git-sync--start))
      (when workflow-git-sync--debounce-timer
        (cancel-timer workflow-git-sync--debounce-timer))
      (setq workflow-git-sync--debounce-timer
            (run-at-time workflow-git-sync-debounce-seconds nil
                         #'workflow-git-sync--start)))))

(defun workflow-git-sync--schedule-pull ()
  "Schedule an immediate full sync run."
  (when workflow-git-sync-mode
    (workflow-git-sync--schedule t)))

(defun workflow-git-sync--start-pull-timer ()
  "Start periodic pull timer when enabled."
  (when workflow-git-sync--pull-timer
    (cancel-timer workflow-git-sync--pull-timer)
    (setq workflow-git-sync--pull-timer nil))
  (when (and workflow-git-sync-auto-pull-enabled
             (> workflow-git-sync-pull-interval-seconds 0))
    (setq workflow-git-sync--pull-timer
          (run-at-time workflow-git-sync-pull-interval-seconds
                       workflow-git-sync-pull-interval-seconds
                       #'workflow-git-sync--schedule-pull))))

(defun workflow-git-sync--stop-pull-timer ()
  "Stop periodic pull timer."
  (when workflow-git-sync--pull-timer
    (cancel-timer workflow-git-sync--pull-timer)
    (setq workflow-git-sync--pull-timer nil)))

(defun workflow-git-sync--all-directories (root)
  "Return ROOT and all non-symlink subdirectories beneath it."
  (let ((dirs (list root)))
    (dolist (entry (directory-files root t directory-files-no-dot-files-regexp))
      (when (and (file-directory-p entry)
                 (not (file-symlink-p entry))
                 (not (string= (file-name-nondirectory entry) ".git")))
        (setq dirs (nconc dirs (workflow-git-sync--all-directories entry)))))
    dirs))

(defun workflow-git-sync--remove-watches ()
  "Remove all registered file notification watches."
  (dolist (descriptor workflow-git-sync--watch-descriptors)
    (ignore-errors (file-notify-rm-watch descriptor)))
  (setq workflow-git-sync--watch-descriptors nil))

(defun workflow-git-sync--watch-callback (event)
  "Handle file notification EVENT by scheduling sync work."
  (unless workflow-git-sync--suppress-file-events
    (pcase-let ((`(,_descriptor ,action ,path . ,rest) event))
      (unless (memq action '(stopped))
        (let ((extra-path (car rest)))
          (unless (or (workflow-git-sync--git-path-p path)
                      (workflow-git-sync--git-path-p extra-path))
            (when (or (workflow-git-sync--path-in-org-p path)
                      (workflow-git-sync--path-in-org-p extra-path))
              (when (memq action '(created deleted renamed))
                (workflow-git-sync--refresh-watches))
              (workflow-git-sync--schedule nil))))))))

(defun workflow-git-sync--refresh-watches ()
  "Rebuild recursive directory watches for workflow org files."
  (workflow-git-sync--remove-watches)
  (when (and (workflow-git-sync--file-notify-available-p)
             (file-directory-p (workflow-git-sync--org-root)))
    (dolist (dir (workflow-git-sync--all-directories (workflow-git-sync--org-root)))
      (push (file-notify-add-watch dir '(change attribute-change)
                                   #'workflow-git-sync--watch-callback)
            workflow-git-sync--watch-descriptors))))

(defun workflow-git-sync--after-save-hook ()
  "Queue sync for saves under `workflow-org-directory'."
  (when (and buffer-file-name
             (workflow-git-sync--path-in-org-p buffer-file-name)
             (not (workflow-git-sync--git-path-p buffer-file-name)))
    (workflow-git-sync--schedule nil)))

(defun workflow-git-sync--run-git (args on-success on-failure)
  "Run git with ARGS asynchronously, then call ON-SUCCESS or ON-FAILURE.
ON-SUCCESS is called with no args. ON-FAILURE is called with stderr/stdout.
Callbacks run only when `workflow-git-sync-mode' is still active."
  (let* ((default-directory (workflow-git-sync--org-root))
         (buffer (get-buffer-create workflow-git-sync--log-buffer)))
    (when (process-live-p workflow-git-sync--process)
      (delete-process workflow-git-sync--process))
    (with-current-buffer buffer
      (erase-buffer))
    (setq workflow-git-sync--process
          (make-process
           :name "workflow-git-sync"
           :buffer buffer
           :command (append (list "git") args)
           :noquery t
           :sentinel
           (lambda (proc _event)
             (when (memq (process-status proc) '(exit signal))
               (let ((output (string-trim
                              (with-current-buffer (process-buffer proc)
                                (buffer-string)))))
                 (if (and workflow-git-sync-mode
                          (= (process-exit-status proc) 0))
                     (funcall on-success)
                    (when workflow-git-sync-mode
                      (funcall on-failure output))))))))))

(defun workflow-git-sync--run-git-blocking (args deadline)
  "Run git ARGS until DEADLINE.
Return plist with keys :status (:ok/:error/:timeout), :code, and :output."
  (let* ((default-directory (workflow-git-sync--org-root))
         (buffer (get-buffer-create workflow-git-sync--log-buffer))
         (proc (make-process
                :name "workflow-git-sync-exit"
                :buffer buffer
                :command (append (list "git") args)
                :noquery t)))
    (with-current-buffer buffer
      (erase-buffer))
    (while (and (process-live-p proc)
                (< (float-time) deadline))
      (accept-process-output proc 0.05))
    (cond
     ((process-live-p proc)
      (delete-process proc)
      (list :status :timeout :code nil :output ""))
     (t
      (let ((output (string-trim
                     (with-current-buffer buffer
                       (buffer-string))))
            (code (process-exit-status proc)))
        (if (= code 0)
            (list :status :ok :code code :output output)
          (list :status :error :code code :output output)))))))

(defun workflow-git-sync--run-git-blocking-ok-p (result)
  "Return non-nil when RESULT from `workflow-git-sync--run-git-blocking' succeeded."
  (eq (plist-get result :status) :ok))

(defun workflow-git-sync--run-git-blocking-timeout-p (result)
  "Return non-nil when RESULT from blocking git call timed out."
  (eq (plist-get result :status) :timeout))

(defun workflow-git-sync--run-git-blocking-code (result)
  "Return exit code from blocking git RESULT."
  (plist-get result :code))

(defun workflow-git-sync--run-git-blocking-output (result)
  "Return output text from blocking git RESULT."
  (plist-get result :output))

(defun workflow-git-sync--exit-flush-error (message-text)
  "Report MESSAGE-TEXT for exit flush errors."
  (message "Workflow git sync failed during exit flush: %s" message-text))

(defun workflow-git-sync--exit-flush ()
  "Attempt one best-effort sync before Emacs exits."
  (when (and workflow-git-sync-mode
             workflow-git-sync-exit-flush-enabled
             (not workflow-git-sync--in-progress)
             (file-directory-p (workflow-git-sync--org-root)))
    (let ((deadline (+ (float-time) (max 0.1 workflow-git-sync-exit-flush-timeout-seconds)))
           result
           had-pending-debounce
           had-staged
           had-upstream-updates
           ahead-count)
      (when workflow-git-sync--debounce-timer
        (setq had-pending-debounce t)
        (cancel-timer workflow-git-sync--debounce-timer)
        (setq workflow-git-sync--debounce-timer nil))
      (when had-pending-debounce
        (message "Workflow git sync: flushing pending changes before exit..."))
      (setq result (workflow-git-sync--run-git-blocking '("rev-parse" "--is-inside-work-tree") deadline))
      (unless (workflow-git-sync--run-git-blocking-ok-p result)
        (cl-return-from workflow-git-sync--exit-flush nil))
      (setq result (workflow-git-sync--run-git-blocking '("rev-parse" "--abbrev-ref" "--symbolic-full-name" "@{u}") deadline))
      (unless (workflow-git-sync--run-git-blocking-ok-p result)
        (cl-return-from workflow-git-sync--exit-flush nil))
      (setq result (workflow-git-sync--run-git-blocking '("add" "-A") deadline))
      (unless (workflow-git-sync--run-git-blocking-ok-p result)
        (workflow-git-sync--exit-flush-error
         (let ((output (workflow-git-sync--run-git-blocking-output result)))
           (if (string-empty-p output) "git add failed" output)))
        (cl-return-from workflow-git-sync--exit-flush nil))
      (setq result (workflow-git-sync--run-git-blocking '("diff" "--cached" "--quiet" "--exit-code") deadline)
            had-staged (= 1 (or (workflow-git-sync--run-git-blocking-code result) 0)))
      (cond
       ((workflow-git-sync--run-git-blocking-timeout-p result)
        (workflow-git-sync--exit-flush-error "timeout checking staged changes")
        (cl-return-from workflow-git-sync--exit-flush nil))
       ((and (not had-staged)
             (not (workflow-git-sync--run-git-blocking-ok-p result)))
        (workflow-git-sync--exit-flush-error "failed checking staged changes")
        (cl-return-from workflow-git-sync--exit-flush nil)))
      (when had-staged
        (setq result (workflow-git-sync--run-git-blocking
                      (list "commit" "-m" (workflow-git-sync--commit-message))
                      deadline))
        (unless (workflow-git-sync--run-git-blocking-ok-p result)
          (workflow-git-sync--exit-flush-error
           (let ((output (workflow-git-sync--run-git-blocking-output result)))
             (if (string-empty-p output) "git commit failed" output)))
          (cl-return-from workflow-git-sync--exit-flush nil)))
      (setq result (workflow-git-sync--run-git-blocking '("fetch" "--prune") deadline))
      (unless (workflow-git-sync--run-git-blocking-ok-p result)
        (workflow-git-sync--exit-flush-error
         (let ((output (workflow-git-sync--run-git-blocking-output result)))
           (if (string-empty-p output) "git fetch failed" output)))
        (cl-return-from workflow-git-sync--exit-flush nil))
      (setq result (workflow-git-sync--run-git-blocking '("rev-list" "--count" "HEAD..@{u}") deadline))
      (unless (workflow-git-sync--run-git-blocking-ok-p result)
        (workflow-git-sync--exit-flush-error
         (let ((output (workflow-git-sync--run-git-blocking-output result)))
           (if (string-empty-p output) "failed checking behind commits" output)))
        (cl-return-from workflow-git-sync--exit-flush nil))
      (setq had-upstream-updates
            (> (string-to-number (workflow-git-sync--run-git-blocking-output result)) 0))
      (setq result (workflow-git-sync--run-git-blocking '("rebase" "@{u}") deadline))
      (unless (workflow-git-sync--run-git-blocking-ok-p result)
        (workflow-git-sync--run-git-blocking '("rebase" "--abort") deadline)
        (workflow-git-sync--exit-flush-error
         (let ((output (workflow-git-sync--run-git-blocking-output result)))
           (if (string-empty-p output) "rebase conflict" output)))
        (cl-return-from workflow-git-sync--exit-flush nil))
      (when had-upstream-updates
        (workflow-git-sync--sync-org-roam-db))
      (setq result (workflow-git-sync--run-git-blocking '("rev-list" "--count" "@{u}..HEAD") deadline))
      (unless (workflow-git-sync--run-git-blocking-ok-p result)
        (workflow-git-sync--exit-flush-error
         (let ((output (workflow-git-sync--run-git-blocking-output result)))
           (if (string-empty-p output) "failed checking ahead commits" output)))
        (cl-return-from workflow-git-sync--exit-flush nil))
      (setq ahead-count (string-to-number (workflow-git-sync--run-git-blocking-output result)))
      (when (> ahead-count 0)
        (setq result (workflow-git-sync--run-git-blocking '("push") deadline))
        (unless (workflow-git-sync--run-git-blocking-ok-p result)
          (workflow-git-sync--exit-flush-error
           (let ((output (workflow-git-sync--run-git-blocking-output result)))
             (if (string-empty-p output) "git push failed" output)))
          (cl-return-from workflow-git-sync--exit-flush nil))))))

(defun workflow-git-sync--finish ()
  "Complete the current run and start another if pending."
  (setq workflow-git-sync--in-progress nil
        workflow-git-sync--suppress-file-events nil
        workflow-git-sync--refresh-buffers-after-rebase nil
        workflow-git-sync--process nil)
  (when workflow-git-sync--pending
    (setq workflow-git-sync--pending nil)
    (workflow-git-sync--schedule t)))

(defun workflow-git-sync--start ()
  "Start a sync run if possible."
  (setq workflow-git-sync--debounce-timer nil)
  (cond
   (workflow-git-sync--in-progress
    (setq workflow-git-sync--pending t))
   ((not (file-directory-p (workflow-git-sync--org-root)))
    (workflow-git-sync--git-error "org directory does not exist")
    (workflow-git-sync--finish))
   (t
    (setq workflow-git-sync--in-progress t)
    (setq workflow-git-sync--suppress-file-events t)
    (setq workflow-git-sync--refresh-buffers-after-rebase nil)
    (workflow-git-sync--preflight))))

(defun workflow-git-sync--preflight ()
  "Validate git repository and upstream before syncing."
  (workflow-git-sync--run-git
   '("rev-parse" "--is-inside-work-tree")
   (lambda ()
     (workflow-git-sync--run-git
      '("rev-parse" "--abbrev-ref" "--symbolic-full-name" "@{u}")
      #'workflow-git-sync--git-add
      (lambda (_output)
        (workflow-git-sync--git-error "current branch has no upstream")
        (workflow-git-sync--finish))))
   (lambda (_output)
     (workflow-git-sync--git-error "org directory is not a git repository")
     (workflow-git-sync--finish))))

(defun workflow-git-sync--git-add ()
  "Run `git add -A'."
  (workflow-git-sync--run-git
   '("add" "-A")
   #'workflow-git-sync--check-staged
   (lambda (output)
     (workflow-git-sync--git-error "%s" (if (string-empty-p output) "git add failed" output))
     (workflow-git-sync--finish))))

(defun workflow-git-sync--check-staged ()
  "Check whether staged changes exist and branch accordingly."
  (workflow-git-sync--run-git
   '("diff" "--cached" "--quiet" "--exit-code")
   #'workflow-git-sync--fetch
   (lambda (_output)
     (if (= (process-exit-status workflow-git-sync--process) 1)
         (workflow-git-sync--git-commit)
       (progn
         (workflow-git-sync--git-error "failed checking staged changes")
         (workflow-git-sync--finish))))))

(defun workflow-git-sync--git-commit ()
  "Create an autosync commit."
  (workflow-git-sync--run-git
   (list "commit" "-m"
         (workflow-git-sync--commit-message))
   #'workflow-git-sync--fetch
   (lambda (output)
     (workflow-git-sync--git-error "%s" (if (string-empty-p output) "git commit failed" output))
     (workflow-git-sync--finish))))

(defun workflow-git-sync--check-ahead ()
  "Push local commits after remote reconciliation."
  (workflow-git-sync--run-git
   '("rev-list" "--count" "@{u}..HEAD")
   (lambda ()
     (let* ((buffer (get-buffer workflow-git-sync--log-buffer))
            (count (if buffer
                       (string-to-number
                        (string-trim (with-current-buffer buffer (buffer-string))))
                     0)))
       (if (> count 0)
           (workflow-git-sync--push)
         (workflow-git-sync--finish))))
   (lambda (output)
     (workflow-git-sync--git-error "%s" (if (string-empty-p output) "failed checking ahead commits" output))
     (workflow-git-sync--finish))))

(defun workflow-git-sync--fetch ()
  "Fetch remote refs."
  (workflow-git-sync--run-git
   '("fetch" "--prune")
   #'workflow-git-sync--check-behind
   (lambda (output)
     (workflow-git-sync--git-error "%s" (if (string-empty-p output) "git fetch failed" output))
     (workflow-git-sync--finish))))

(defun workflow-git-sync--check-behind ()
  "Check whether upstream has commits not yet in local HEAD."
  (workflow-git-sync--run-git
   '("rev-list" "--count" "HEAD..@{u}")
   (lambda ()
     (let* ((buffer (get-buffer workflow-git-sync--log-buffer))
            (count (if buffer
                       (string-to-number
                        (string-trim (with-current-buffer buffer (buffer-string))))
                     0)))
       (setq workflow-git-sync--refresh-buffers-after-rebase (> count 0))
       (workflow-git-sync--rebase)))
   (lambda (output)
     (workflow-git-sync--git-error "%s" (if (string-empty-p output) "failed checking behind commits" output))
     (workflow-git-sync--finish))))

(defun workflow-git-sync--rebase ()
  "Rebase local branch onto upstream."
  (workflow-git-sync--run-git
   '("rebase" "@{u}")
   (lambda ()
     (when workflow-git-sync--refresh-buffers-after-rebase
       (workflow-git-sync--refresh-org-buffers)
       (workflow-git-sync--sync-org-roam-db))
     (workflow-git-sync--check-ahead))
   (lambda (output)
     (workflow-git-sync--run-git
      '("rebase" "--abort")
      (lambda ()
        (workflow-git-sync--git-error "%s" (if (string-empty-p output) "rebase conflict" output))
        (workflow-git-sync--finish))
      (lambda (_abort-output)
        (workflow-git-sync--git-error "%s" (if (string-empty-p output) "rebase conflict" output))
        (workflow-git-sync--finish))))))

(defun workflow-git-sync--push ()
  "Push local branch to upstream."
  (workflow-git-sync--run-git
   '("push")
   #'workflow-git-sync--finish
   (lambda (output)
     (workflow-git-sync--git-error "%s" (if (string-empty-p output) "git push failed" output))
     (workflow-git-sync--finish))))

(defun workflow-git-sync--refresh-org-buffers ()
  "Revert unmodified buffers visiting files under workflow org root."
  (let ((skipped 0)
        (reverted 0))
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (when (and buffer-file-name
                   (workflow-git-sync--path-in-org-p buffer-file-name)
                   (file-exists-p buffer-file-name))
          (if (buffer-modified-p)
              (setq skipped (1+ skipped))
            (revert-buffer :ignore-auto :noconfirm)
            (setq reverted (1+ reverted))))))
    (when (> reverted 0)
      (message "Workflow git sync: refreshed %d open unmodified buffer(s) with synced content" reverted))
    (when (> skipped 0)
      (message "Workflow git sync: skipped %d modified buffer(s) after pull" skipped))))

(defun workflow-git-sync-now ()
  "Trigger an immediate sync run."
  (interactive)
  (workflow-git-sync--schedule t))

(defun workflow-git-sync-pull-now ()
  "Trigger an immediate upstream reconciliation run."
  (interactive)
  (workflow-git-sync--schedule-pull))

;;;###autoload
(define-minor-mode workflow-git-sync-mode
  "Automatically sync `workflow-org-directory' to git remote."
  :global t
  :group 'workflow-git-sync
  (if workflow-git-sync-mode
      (progn
        (add-hook 'after-save-hook #'workflow-git-sync--after-save-hook)
        (setq workflow-git-sync--suppress-file-events nil
              workflow-git-sync--pending nil)
        (if (workflow-git-sync--file-notify-available-p)
            (workflow-git-sync--refresh-watches)
          (message "Workflow git sync: file notifications unavailable; using save hook only"))
        (add-hook 'kill-emacs-hook #'workflow-git-sync--exit-flush)
        (workflow-git-sync--start-pull-timer)
        (workflow-git-sync--schedule-pull))
    (remove-hook 'after-save-hook #'workflow-git-sync--after-save-hook)
    (when workflow-git-sync--debounce-timer
      (cancel-timer workflow-git-sync--debounce-timer)
      (setq workflow-git-sync--debounce-timer nil))
    (remove-hook 'kill-emacs-hook #'workflow-git-sync--exit-flush)
    (workflow-git-sync--stop-pull-timer)
    (workflow-git-sync--remove-watches)
    (when (process-live-p workflow-git-sync--process)
      (delete-process workflow-git-sync--process))
    (setq workflow-git-sync--in-progress nil
          workflow-git-sync--pending nil
          workflow-git-sync--suppress-file-events nil
          workflow-git-sync--refresh-buffers-after-rebase nil
          workflow-git-sync--process nil)))

(when workflow-git-sync-enabled
  (workflow-git-sync-mode 1))

(provide 'workflow-git-sync)
