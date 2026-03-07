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

(defun workflow-org--refill-safe-p ()
  "Return non-nil when point is in prose that should be refilled."
  (let ((type (org-element-type (org-element-context))))
    (not (memq type
               '(babel-call comment comment-block drawer dynamic-block fixed-width
                 example-block headline inline-src-block keyword node-property
                 planning property-drawer src-block table table-row verse-block)))))

(defun workflow-org--refill-after-insert ()
  "Aggressively refill Org prose after typing."
  (when (and (workflow-org--refill-safe-p)
             (not (and (memq last-command-event '(?\s ?\t))
                       (eolp))))
    (save-excursion
      (org-fill-paragraph nil))))

(defun workflow-org--setup-fill ()
  "Configure aggressive wrapping for Org prose at 80 columns."
  (setq-local fill-column 80)
  (auto-fill-mode -1)
  (refill-mode -1)
  (add-hook 'post-self-insert-hook #'workflow-org--refill-after-insert nil t))

(use-package org
  :ensure nil
  :hook (org-mode . workflow-org--setup-fill)
  :config
  (setq org-log-done 'time))

(provide 'org-core)
