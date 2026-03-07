;;; org-roam-config.el --- Org-roam database and capture templates  -*- lexical-binding: t; -*-
;;
;; This file configures Org-roam for one-note-per-file workflow, enables
;; autosync, and defines capture templates for idea/task/resolved/ref notes.

(require 'org-core)
(require 'seq)

(use-package org-roam
  :init
  (setq org-roam-directory (file-truename workflow-roam-directory)
        org-roam-completion-everywhere t)
  :config
  (add-hook 'org-capture-mode-hook #'delete-other-windows)
  (dolist (subdir '("idea" "task" "resolved" "reference"))
    (make-directory (expand-file-name subdir org-roam-directory) t))
  (org-roam-db-autosync-mode 1)
  (setq org-roam-node-display-template
        (concat "${title:*} "
                (propertize "${tags:40}" 'face 'org-tag)))

  (setq org-roam-capture-templates
        '(("i" "idea" plain
           "* Context\n\n* Notes\n\n* Links\n"
           :if-new (file+head "idea/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+created: %U\n#+filetags: :idea:\n\n")
           :unnarrowed t)
          ("t" "task" plain
           "* Objective\n\n* Done Criteria\n\n* Implementation Notes\n\n* Links\n"
           :if-new (file+head "task/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+created: %U\n#+filetags: :task:\n\n")
           :unnarrowed t)
          ("r" "resolved" plain
           "* Resolution Reason\n\n* Consequences\n\n* Follow-ups\n\n* Links\n"
           :if-new (file+head "resolved/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+created: %U\n#+filetags: :resolved:\n\n")
           :unnarrowed t)
          ("f" "reference" plain
           "* Source\n\n* Summary\n\n* Notes\n\n* Links\n"
           :if-new (file+head "reference/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+created: %U\n#+filetags: :ref:\n\n")
           :unnarrowed t))))

(defun workflow--roam-template-for-key (key)
  "Return the Org-roam template matching KEY."
  (or (seq-find (lambda (template) (string= (car template) key))
                org-roam-capture-templates)
      (user-error "No Org-roam template found for key: %s" key)))

(defun workflow-roam-capture-by-key (key)
  "Create a new Org-roam note using template KEY."
  (delete-other-windows)
  (org-roam-capture-
   :node (org-roam-node-create)
   :templates (list (workflow--roam-template-for-key key))
   :props '(:finalize find-file)))

(defun workflow-capture-quick ()
  "Capture a quick idea note without prompting for title."
  (interactive)
  (delete-other-windows)
  (org-roam-capture-
   :node (org-roam-node-create :title (format-time-string "%Y-%m-%d %H:%M"))
   :templates
   '(("q" "quick" plain
      "* Notes\n\n* Links\n"
      :if-new (file+head "idea/%<%Y%m%d%H%M%S>-${slug}.org"
                         "#+title: ${title}\n#+created: %U\n#+filetags: :idea:quick:\n\n")
      :unnarrowed t))
   :props '(:finalize find-file)))

(defun workflow-capture-idea ()
  "Capture an idea note."
  (interactive)
  (workflow-roam-capture-by-key "i"))

(defun workflow-capture-task ()
  "Capture a task note."
  (interactive)
  (workflow-roam-capture-by-key "t"))

(defun workflow-capture-resolved ()
  "Capture a resolved note."
  (interactive)
  (workflow-roam-capture-by-key "r"))

(defun workflow-capture-reference ()
  "Capture a reference note."
  (interactive)
  (workflow-roam-capture-by-key "f"))

(provide 'org-roam-config)
