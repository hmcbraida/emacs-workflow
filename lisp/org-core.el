;;; org-core.el --- Base Org directories and defaults  -*- lexical-binding: t; -*-
;;
;; This file defines core Org paths and behavior for the workflow system.
;; It creates required directories and sets baseline Org settings.

(require 'org)

(defgroup workflow nil
  "Personal workflow settings."
  :group 'applications)

(defcustom workflow-org-directory (expand-file-name "~/org/")
  "Root directory for workflow data."
  :type 'directory
  :group 'workflow)

(defcustom workflow-roam-directory (expand-file-name "roam/" workflow-org-directory)
  "Directory containing Org-roam notes."
  :type 'directory
  :group 'workflow)

(defcustom workflow-assets-directory (expand-file-name "assets/" workflow-org-directory)
  "Directory for workflow assets, including images."
  :type 'directory
  :group 'workflow)

(defcustom workflow-inbox-file (expand-file-name "inbox.org" workflow-org-directory)
  "Fallback inbox file for quick capture."
  :type 'file
  :group 'workflow)

(dolist (dir (list workflow-org-directory workflow-roam-directory workflow-assets-directory))
  (make-directory dir t))

(unless (file-exists-p workflow-inbox-file)
  (with-temp-buffer
    (insert "#+title: Inbox\n\n")
    (write-file workflow-inbox-file)))

(setq org-directory workflow-org-directory
      org-default-notes-file workflow-inbox-file
      org-capture-window-setup 'delete-other-windows
      org-return-follows-link t
      org-startup-folded 'content
      org-hide-emphasis-markers t)

(setq org-id-locations-file (expand-file-name ".org-id-locations" workflow-org-directory))

(unless (file-exists-p org-id-locations-file)
  (with-temp-file org-id-locations-file
    (prin1 '() (current-buffer))))

(use-package org
  :ensure nil
  :config
  (setq org-log-done 'time))

(provide 'org-core)
