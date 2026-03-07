;;; workflow-triage.el --- Triage tools for quick capture notes  -*- lexical-binding: t; -*-
;;
;; This file provides quick-note triage commands: find quick captures,
;; process current quick note, and run an inbox-style one-by-one triage loop.

(require 'org)
(require 'org-roam)
(require 'seq)
(require 'subr-x)
(require 'workflow-lifecycle)

(defun workflow-triage--quick-nodes ()
  "Return Org-roam nodes tagged with `quick'."
  (let ((nodes (seq-filter
                (lambda (node)
                  (member "quick" (org-roam-node-tags node)))
                (org-roam-node-list))))
    (seq-sort-by #'org-roam-node-file-mtime #'time-less-p nodes)))

(defun workflow-triage--set-current-filetags (tags)
  "Set current note file TAGS exactly."
  (let ((cleaned (seq-uniq (seq-filter (lambda (tag) (not (string-empty-p tag))) tags))))
    (org-roam-set-keyword "filetags" (org-make-tag-string cleaned))))

(defun workflow-triage--update-current-filetags (add remove)
  "Add tags in ADD and remove tags in REMOVE for current note."
  (let* ((current (split-string
                   (or (cadr (assoc "FILETAGS" (org-collect-keywords '("FILETAGS")))) "")
                   ":" t))
         (after-remove (seq-difference current remove #'string-equal))
         (result (append add after-remove)))
    (workflow-triage--set-current-filetags result)
    (save-buffer)
    (org-roam-db-update-file)
    result))

(defun workflow-triage-find-quick-note ()
  "Find a note tagged `quick'."
  (interactive)
  (org-roam-node-find
   nil nil
   (lambda (node) (member "quick" (org-roam-node-tags node)))
   nil))

(defun workflow-triage-mark-as-idea ()
  "Mark current quick note as a structured idea (remove `quick', keep `idea')."
  (interactive)
  (workflow-triage--update-current-filetags '("idea") '("quick"))
  (message "Marked note as idea and removed quick tag"))

(defun workflow-triage-archive-current ()
  "Archive current quick note by tagging it `archived' and removing `quick'."
  (interactive)
  (workflow-triage--update-current-filetags '("archived") '("quick"))
  (message "Archived note and removed quick tag"))

(defun workflow-triage-cancel-current ()
  "Cancel current quick note by tagging it `cancelled' and removing `quick'."
  (interactive)
  (workflow-triage--update-current-filetags '("cancelled") '("quick"))
  (message "Cancelled note and removed quick tag"))

(defun workflow-triage-promote-current-to-task ()
  "Promote current quick/idea note into one or more tasks and remove `quick'."
  (interactive)
  (let ((source-buffer (current-buffer)))
    (unless (member "idea" (split-string
                            (or (cadr (assoc "FILETAGS" (org-collect-keywords '("FILETAGS")))) "")
                            ":" t))
      (workflow-triage--update-current-filetags '("idea") nil))
    (call-interactively #'workflow-promote-idea-to-tasks)
    (when (buffer-live-p source-buffer)
      (with-current-buffer source-buffer
        (workflow-triage--update-current-filetags nil '("quick")))))
  (message "Promoted note to task(s) and removed quick tag"))

(defun workflow-triage-current-note ()
  "Run one triage action for the current note.
Supported actions: idea, task, archive, cancel, skip."
  (interactive)
  (let ((action (completing-read
                 "Triage action: "
                 '("idea" "task" "archive" "cancel" "skip")
                 nil t)))
    (pcase action
      ("idea" (workflow-triage-mark-as-idea))
      ("task" (workflow-triage-promote-current-to-task))
      ("archive" (workflow-triage-archive-current))
      ("cancel" (workflow-triage-cancel-current))
      (_ (message "Skipped note")))))

(defun workflow-triage-loop ()
  "Process quick notes one-by-one until empty or user quits."
  (interactive)
  (let ((continue t))
    (while continue
      (let ((nodes (workflow-triage--quick-nodes)))
        (if (null nodes)
            (progn
              (setq continue nil)
              (message "No quick notes left to triage"))
          (find-file (org-roam-node-file (car nodes)))
          (when (derived-mode-p 'org-mode)
            (org-fold-show-all)
            (goto-char (point-min))
            (recenter 0))
          (let ((action (completing-read
                         (format "Triage %s: " (org-roam-node-title (car nodes)))
                         '("idea" "task" "archive" "cancel" "skip" "quit")
                         nil t)))
            (pcase action
              ("idea" (workflow-triage-mark-as-idea))
              ("task" (workflow-triage-promote-current-to-task))
              ("archive" (workflow-triage-archive-current))
              ("cancel" (workflow-triage-cancel-current))
              ("skip" (message "Skipped note"))
              ("quit" (setq continue nil)))))))))

(provide 'workflow-triage)
