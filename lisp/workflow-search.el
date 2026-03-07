;;; workflow-search.el --- Search and saved workflow views  -*- lexical-binding: t; -*-
;;
;; This file defines regex search and saved note views for the workflow:
;; open tasks, active tasks, recent resolved notes, quick inbox, and tasks
;; linked to the current note.

(require 'consult)
(require 'org)
(require 'org-id)
(require 'org-core)
(require 'org-roam)
(require 'org-roam-mode)
(require 'seq)
(require 'subr-x)

(defcustom workflow-task-terminal-tags '("resolved" "cancelled" "archived")
  "Tags that indicate a task is no longer open."
  :type '(repeat string)
  :group 'workflow)

(defun workflow-search-notes ()
  "Run regex search scoped to the workflow notes directory."
  (interactive)
  (consult-ripgrep workflow-org-directory))

(defun workflow--node-has-tag-p (node tag)
  "Return non-nil when NODE has TAG."
  (member tag (org-roam-node-tags node)))

(defun workflow--node-has-any-tag-p (node tags)
  "Return non-nil when NODE has any tag in TAGS."
  (seq-some (lambda (tag) (workflow--node-has-tag-p node tag)) tags))

(defun workflow--open-task-node-p (node)
  "Return non-nil when NODE is an open task by tag semantics."
  (and (workflow--node-has-tag-p node "task")
       (not (workflow--node-has-any-tag-p node workflow-task-terminal-tags))))

(defun workflow--active-task-node-p (node)
  "Return non-nil when NODE is open and not blocked."
  (and (workflow--open-task-node-p node)
       (not (workflow--node-has-tag-p node "blocked"))))

(defun workflow--nodes-sorted-by-mtime-desc (nodes)
  "Return NODES sorted by file modification time, newest first."
  (seq-sort-by #'org-roam-node-file-mtime
               (lambda (a b) (time-less-p b a))
               nodes))

(defun workflow--select-and-visit-node (nodes prompt)
  "Prompt with PROMPT to select one of NODES, then visit it."
  (if (null nodes)
      (message "No matching notes")
    (let* ((pairs (mapcar
                   (lambda (node)
                     (cons (format "%s [%s]"
                                   (org-roam-node-title node)
                                   (string-join (org-roam-node-tags node) ","))
                           node))
                   nodes))
           (choice (completing-read prompt (mapcar #'car pairs) nil t))
           (node (cdr (assoc choice pairs))))
      (when node
        (org-roam-node-visit node)
        (workflow-show-related-notes)))))

(defun workflow-view-open-tasks ()
  "Select and visit an open task.
Open means tagged `task' and missing terminal tags in `workflow-task-terminal-tags'."
  (interactive)
  (workflow--select-and-visit-node
   (workflow--nodes-sorted-by-mtime-desc
    (seq-filter #'workflow--open-task-node-p (org-roam-node-list)))
   "Open task: "))

(defun workflow-view-active-tasks ()
  "Select and visit an active task.
Active means open and not tagged `blocked'."
  (interactive)
  (workflow--select-and-visit-node
   (workflow--nodes-sorted-by-mtime-desc
    (seq-filter #'workflow--active-task-node-p (org-roam-node-list)))
   "Active task: "))

(defun workflow-view-recent-resolved ()
  "Select and visit a recent resolved note."
  (interactive)
  (workflow--select-and-visit-node
   (workflow--nodes-sorted-by-mtime-desc
    (seq-filter (lambda (node) (workflow--node-has-tag-p node "resolved"))
                (org-roam-node-list)))
   "Recent resolved: "))

(defun workflow-view-quick-inbox ()
  "Select and visit a quick-capture note."
  (interactive)
  (workflow--select-and-visit-node
   (workflow--nodes-sorted-by-mtime-desc
    (seq-filter (lambda (node) (workflow--node-has-tag-p node "quick"))
                (org-roam-node-list)))
   "Quick note: "))

(defun workflow--current-note-id-or-error ()
  "Return current note ID or signal a user error."
  (or (org-id-get)
      (user-error "Current note has no ID")))

(defun workflow-view-linked-tasks-for-current-note ()
  "Select and visit tasks directly linked to the current note.
Includes outgoing links from current note and backlinks to it."
  (interactive)
  (let* ((id (workflow--current-note-id-or-error))
         (incoming-ids (mapcar #'car
                               (org-roam-db-query
                                [:select :distinct [source]
                                 :from links
                                 :where (= dest $s1)
                                 :and (= type "id")]
                                id)))
         (outgoing-ids (mapcar #'car
                               (org-roam-db-query
                                [:select :distinct [dest]
                                 :from links
                                 :where (= source $s1)
                                 :and (= type "id")]
                                id)))
         (all-ids (seq-uniq (append incoming-ids outgoing-ids)))
         (nodes (delq nil (mapcar #'org-roam-node-from-id all-ids)))
         (task-nodes (workflow--nodes-sorted-by-mtime-desc
                      (seq-filter (lambda (node) (workflow--node-has-tag-p node "task"))
                                  nodes))))
    (workflow--select-and-visit-node task-nodes "Linked task: ")))

(defun workflow-show-related-notes ()
  "Show Org-roam related notes buffer for the current note."
  (interactive)
  (unless (get-buffer-window org-roam-buffer)
    (org-roam-buffer-toggle))
  (org-roam-buffer-persistent-redisplay))

(provide 'workflow-search)
