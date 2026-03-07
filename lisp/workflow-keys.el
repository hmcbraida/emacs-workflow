;;; workflow-keys.el --- Central keybindings for note workflow  -*- lexical-binding: t; -*-
;;
;; This file defines the `C-c n' prefix map and binds the core commands for
;; capture, navigation, linking, and search within the workflow system.

(require 'org)
(require 'org-roam)
(require 'org-roam-config)
(require 'workflow-lifecycle)
(require 'workflow-triage)

(defvar workflow-notes-map (make-sparse-keymap)
  "Keymap for personal workflow commands.")

(defun workflow-search-notes ()
  "Run regex search scoped to the workflow notes directory."
  (interactive)
  (consult-ripgrep workflow-org-directory))

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

;; Lifecycle transitions
(define-key workflow-notes-map (kbd "p") #'workflow-promote-idea-to-tasks)
(define-key workflow-notes-map (kbd "x") #'workflow-resolve-task)

;; Triage
(define-key workflow-notes-map (kbd "q f") #'workflow-triage-find-quick-note)
(define-key workflow-notes-map (kbd "q t") #'workflow-triage-current-note)
(define-key workflow-notes-map (kbd "q l") #'workflow-triage-loop)

(provide 'workflow-keys)
