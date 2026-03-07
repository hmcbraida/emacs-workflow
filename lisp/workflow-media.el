;;; workflow-media.el --- Image capture and inline media helpers  -*- lexical-binding: t; -*-
;;
;; This file configures image capture for workflow notes using org-download.
;; Images are stored under the workflow assets directory and inserted as links.

(require 'org)
(require 'org-core)

(use-package org-download
  :after org
  :init
  (setq org-image-actual-width t
        org-download-heading-lvl nil
        org-download-method 'directory)
  :config
  (defun workflow-media--image-dir-for-buffer ()
    "Return a date-scoped image directory under `workflow-assets-directory'."
    (expand-file-name (format-time-string "%Y/%m/") workflow-assets-directory))

  (defun workflow-media--setup-org-download-dir ()
    "Set per-buffer org-download image directory for workflow notes.
When outside the workflow notes tree, keep global defaults unchanged."
    (when (and buffer-file-name
               (string-prefix-p (file-truename workflow-org-directory)
                                (file-truename (file-name-directory buffer-file-name))))
      (setq-local org-download-image-dir (workflow-media--image-dir-for-buffer))))

  (add-hook 'org-mode-hook #'workflow-media--setup-org-download-dir)

  (defun workflow-media-insert-from-clipboard ()
    "Insert image from clipboard into current Org note and show inline."
    (interactive)
    (unless (derived-mode-p 'org-mode)
      (user-error "Image insertion expects an Org buffer"))
    (let ((dir (or org-download-image-dir (workflow-media--image-dir-for-buffer))))
      (make-directory dir t)
      (setq-local org-download-image-dir dir)
      (org-download-clipboard)
      (org-display-inline-images)))

  (defun workflow-media-screenshot ()
    "Take screenshot into current Org note and show inline."
    (interactive)
    (unless (derived-mode-p 'org-mode)
      (user-error "Screenshot insertion expects an Org buffer"))
    (let ((dir (or org-download-image-dir (workflow-media--image-dir-for-buffer))))
      (make-directory dir t)
      (setq-local org-download-image-dir dir)
      (org-download-screenshot)
      (org-display-inline-images))))

(provide 'workflow-media)
