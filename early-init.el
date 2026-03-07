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

;; Keep startup responsive; restore normal values after init.
(defvar workflow/default-gc-cons-threshold gc-cons-threshold)
(setq gc-cons-threshold (* 64 1024 1024)
      gc-cons-percentage 0.6)

(add-hook
 'emacs-startup-hook
 (lambda ()
   (setq gc-cons-threshold workflow/default-gc-cons-threshold
         gc-cons-percentage 0.1)))
