;;; workflow-keys.el --- Central keybindings for note workflow  -*- lexical-binding: t; -*-
;;
;; This file defines the `C-c n' prefix map and binds the core commands for
;; capture, navigation, linking, and search within the workflow system.

(require 'org)
(require 'org-roam)
(require 'org-roam-config)
(require 'workflow-lifecycle)
(require 'workflow-triage)
(require 'workflow-search)
(require 'workflow-media)

(defvar workflow-notes-map (make-sparse-keymap)
  "Keymap for personal workflow commands.")

(define-key global-map (kbd "C-c n") workflow-notes-map)

;; Capture
(define-key workflow-notes-map (kbd "i") #'workflow-capture-idea)
(define-key workflow-notes-map (kbd "t") #'workflow-capture-task)
(define-key workflow-notes-map (kbd "r") #'workflow-capture-resolved)
(define-key workflow-notes-map (kbd "f") #'workflow-capture-reference)
(define-key workflow-notes-map (kbd "c") #'workflow-capture-quick)

;; Navigation
(define-key workflow-notes-map (kbd "n") #'org-roam-node-find)
(define-key workflow-notes-map (kbd "b") #'org-roam-buffer-toggle)
(define-key workflow-notes-map (kbd "I") #'org-roam-node-insert)

;; Linking and search
(define-key workflow-notes-map (kbd "l") #'org-store-link)
(define-key workflow-notes-map (kbd "s") #'workflow-search-notes)
(define-key workflow-notes-map (kbd "g a") #'org-roam-tag-add)

;; Saved views
(define-key workflow-notes-map (kbd "v t") #'workflow-view-open-tasks)
(define-key workflow-notes-map (kbd "v a") #'workflow-view-active-tasks)
(define-key workflow-notes-map (kbd "v r") #'workflow-view-recent-resolved)
(define-key workflow-notes-map (kbd "v q") #'workflow-view-quick-inbox)
(define-key workflow-notes-map (kbd "v l") #'workflow-view-linked-tasks-for-current-note)
(define-key workflow-notes-map (kbd "v b") #'workflow-show-related-notes)

;; Lifecycle transitions
(define-key workflow-notes-map (kbd "p") #'workflow-promote-idea-to-tasks)
(define-key workflow-notes-map (kbd "x") #'workflow-resolve-task)

;; Triage
(define-key workflow-notes-map (kbd "q f") #'workflow-triage-find-quick-note)
(define-key workflow-notes-map (kbd "q t") #'workflow-triage-current-note)
(define-key workflow-notes-map (kbd "q l") #'workflow-triage-loop)

;; Media
(define-key workflow-notes-map (kbd "m p") #'workflow-media-insert-from-clipboard)
(define-key workflow-notes-map (kbd "m s") #'workflow-media-screenshot)
(define-key workflow-notes-map (kbd "m i") #'org-toggle-inline-images)

(provide 'workflow-keys)
