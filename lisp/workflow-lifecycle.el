;;; workflow-lifecycle.el --- Idea/task/resolved transition commands  -*- lexical-binding: t; -*-
;;
;; This file implements lifecycle operations for workflow notes:
;; promoting an idea into one or more tasks, and resolving a task into
;; a resolved note with required transition validation.

(require 'org)
(require 'org-id)
(require 'org-roam)
(require 'seq)
(require 'subr-x)

(defun workflow--current-note-id ()
  "Return current note ID, creating one when missing."
  (org-with-wide-buffer
   (save-excursion
     (goto-char (point-min))
     (org-id-get-create))))

(defun workflow--current-note-title ()
  "Return current note title or a filename fallback."
  (let* ((kw (assoc "TITLE" (org-collect-keywords '("TITLE"))))
         (title (car (cdr kw))))
    (if (and title (not (string-empty-p (string-trim title))))
        (string-trim title)
      (file-name-base (or (buffer-file-name) (buffer-name))))))

(defun workflow--filetags ()
  "Return filetags for current buffer as a list of tag strings."
  (let* ((kw (assoc "FILETAGS" (org-collect-keywords '("FILETAGS"))))
         (raw (car (cdr kw)))
         (parts (and raw (split-string raw ":" t))))
    (or parts '())))

(defun workflow--file-has-tag-p (tag)
  "Return non-nil when current note has file TAG."
  (member tag (workflow--filetags)))

(defun workflow--set-current-filetags (tags)
  "Set current note file TAGS exactly."
  (let ((cleaned (seq-uniq (seq-filter (lambda (tag) (not (string-empty-p tag))) tags))))
    (org-roam-set-keyword "filetags" (org-make-tag-string cleaned))
    (save-buffer)
    (org-roam-db-update-file)
    cleaned))

(defun workflow--update-current-filetags (add remove)
  "Add tags in ADD and remove tags in REMOVE for current note."
  (let* ((current (workflow--filetags))
         (after-remove (seq-difference current remove #'string-equal))
         (result (append add after-remove)))
    (workflow--set-current-filetags result)))

(defun workflow--note-timestamp ()
  "Return a compact timestamp suitable for note filenames."
  (format-time-string "%Y%m%d%H%M%S%N"))

(defun workflow--unique-note-path (subdir title)
  "Return a unique note path under SUBDIR for TITLE."
  (let* ((base-dir (expand-file-name subdir org-roam-directory))
         (slug (org-roam-node-slugify title))
         (base (expand-file-name (format "%s-%s.org"
                                         (workflow--note-timestamp)
                                         slug)
                                 base-dir))
         (path base)
         (counter 1))
    (while (file-exists-p path)
      (setq path (expand-file-name
                  (format "%s-%s-%d.org"
                          (workflow--note-timestamp)
                          slug
                          counter)
                  base-dir)
            counter (1+ counter)))
    path))

(defun workflow--write-note-file (subdir title filetags body)
  "Create a new note in SUBDIR with TITLE, FILETAGS, and BODY.
Return a cons cell of (PATH . ID)."
  (let* ((id (org-id-new))
         (path (workflow--unique-note-path subdir title))
         (created (format-time-string "[%Y-%m-%d %a %H:%M]")))
    (make-directory (file-name-directory path) t)
    (with-temp-file path
      (insert ":PROPERTIES:\n")
      (insert (format ":ID: %s\n" id))
      (insert ":END:\n\n")
      (insert (format "#+title: %s\n" title))
      (insert (format "#+created: %s\n" created))
      (insert (format "#+filetags: :%s:\n\n" filetags))
      (insert body)
      (unless (string-suffix-p "\n" body)
        (insert "\n")))
    (cons path id)))

(defun workflow--split-task-titles (input)
  "Split INPUT on semicolons into cleaned task titles."
  (mapcar #'string-trim
          (seq-filter
           (lambda (s) (not (string-empty-p s)))
           (split-string input ";"))))

(defun workflow--section-content (heading)
  "Return trimmed content under first top-level HEADING, or empty string."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward (format "^\\* +%s\\s-*$" (regexp-quote heading)) nil t)
        (let ((start (line-beginning-position 2))
              (end (or (save-excursion
                         (when (re-search-forward "^\\* " nil t)
                           (line-beginning-position)))
                       (point-max))))
          (string-trim (buffer-substring-no-properties start end)))
      "")))

(defun workflow--append-link-under-heading (heading link-line)
  "Append LINK-LINE under top-level HEADING in current note."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward (format "^\\* +%s\\s-*$" (regexp-quote heading)) nil t)
        (progn
          (goto-char (or (save-excursion
                           (when (re-search-forward "^\\* " nil t)
                             (line-beginning-position)))
                         (point-max)))
          (unless (bolp)
            (insert "\n"))
          (insert link-line "\n"))
      (goto-char (point-max))
      (unless (bolp)
        (insert "\n"))
      (insert "\n* " heading "\n" link-line "\n"))))

(defun workflow-promote-idea-to-tasks (titles-input)
  "Promote current idea note into one or more task notes.
TITLES-INPUT is a semicolon-separated list of task titles."
  (interactive
   (list
    (read-string "Task title(s), separated by ';': ")))
  (unless (workflow--file-has-tag-p "idea")
    (user-error "Current note is not tagged :idea:"))
  (let* ((titles (workflow--split-task-titles titles-input))
         (source-id (workflow--current-note-id))
         (source-title (workflow--current-note-title))
         (created '()))
    (unless titles
      (user-error "Please provide at least one task title"))
    (dolist (title titles)
      (let* ((body (format "* Objective\n%s\n\n* Done Criteria\n\n* Implementation Notes\n\n* Links\n- Promoted from [[id:%s][%s]]\n"
                           title source-id source-title))
             (created-note (workflow--write-note-file "task" title "task" body)))
        (push (list title (car created-note) (cdr created-note)) created)))
    (org-roam-db-sync)
    (let* ((ordered (nreverse created))
           (first-path (cadr (car ordered))))
      (dolist (entry ordered)
        (workflow--append-link-under-heading
         "Links"
         (format "- Spawned task [[id:%s][%s]]" (nth 2 entry) (car entry))))
      (save-buffer)
      (find-file first-path)
      (message "Created %d task note(s) from idea" (length ordered)))))

(defun workflow-resolve-task ()
  "Resolve current task note into a resolved note with required fields."
  (interactive)
  (unless (workflow--file-has-tag-p "task")
    (user-error "Current note is not tagged :task:"))
  (let* ((done-criteria (workflow--section-content "Done Criteria"))
         (source-id (workflow--current-note-id))
         (source-title (workflow--current-note-title)))
    (when (string-empty-p done-criteria)
      (user-error "Cannot resolve task: 'Done Criteria' section is empty"))
    (let* ((resolution-reason (string-trim (read-string "Resolution reason: ")))
           (consequences (string-trim (read-string "Consequences: ")))
           (resolved-title (format "Resolved: %s" source-title)))
      (when (string-empty-p resolution-reason)
        (user-error "Resolution reason is required"))
      (when (string-empty-p consequences)
        (user-error "Consequences are required"))
      (let* ((body (format "* Resolution Reason\n%s\n\n* Consequences\n%s\n\n* Follow-ups\n\n* Links\n- Resolved from [[id:%s][%s]]\n"
                         resolution-reason consequences source-id source-title))
             (created-note (workflow--write-note-file "resolved" resolved-title "resolved" body))
             (resolved-path (car created-note))
             (resolved-id (cdr created-note)))
        (org-roam-db-sync)
        (workflow--append-link-under-heading
         "Links"
         (format "- Resolved as [[id:%s][%s]]" resolved-id resolved-title))
        (workflow--update-current-filetags '("resolved") nil)
        (save-buffer)
        (find-file resolved-path)
        (message "Task resolved and linked")))))

(provide 'workflow-lifecycle)
