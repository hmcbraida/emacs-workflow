;;; early-init.el --- Startup defaults and performance tuning  -*- lexical-binding: t; -*-
;;
;; This file applies early startup defaults: package startup behavior,
;; initial UI simplifications, and conservative GC tuning for faster launch.

(setq package-enable-at-startup nil)

(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

(add-to-list 'initial-frame-alist '(fullscreen . maximized))
(add-to-list 'default-frame-alist '(fullscreen . maximized))

;; Keep auto-save, backup, and lock files inside this config directory.
(let* ((workflow-var-dir (expand-file-name "var/" user-emacs-directory))
       (workflow-backup-dir (expand-file-name "backups/" workflow-var-dir))
       (workflow-autosave-dir (expand-file-name "auto-saves/" workflow-var-dir))
       (workflow-lockfiles-dir (expand-file-name "lock-files/" workflow-var-dir)))
  (dolist (dir (list workflow-var-dir
                     workflow-backup-dir
                     workflow-autosave-dir
                     workflow-lockfiles-dir))
    (make-directory dir t))
  (setq backup-directory-alist `(("." . ,workflow-backup-dir))
        auto-save-file-name-transforms `((".*" ,workflow-autosave-dir t))
        auto-save-list-file-prefix (expand-file-name ".saves-" workflow-autosave-dir)
        lock-file-name-transforms `((".*" ,workflow-lockfiles-dir t))))

;; Keep startup responsive; restore normal values after init.
(defvar workflow/default-gc-cons-threshold gc-cons-threshold)
(setq gc-cons-threshold (* 64 1024 1024)
      gc-cons-percentage 0.6)

(add-hook
 'emacs-startup-hook
 (lambda ()
   (setq gc-cons-threshold workflow/default-gc-cons-threshold
         gc-cons-percentage 0.1)))
