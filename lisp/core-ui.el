;;; core-ui.el --- Completion and navigation UX defaults  -*- lexical-binding: t; -*-
;;
;; This file configures minibuffer completion and discovery tools used across
;; the workflow: Vertico, Orderless, Marginalia, Consult, and Savehist.

(use-package emacs
  :init
  (setq completion-cycle-threshold 3
        tab-always-indent 'complete
        read-buffer-completion-ignore-case t
        read-file-name-completion-ignore-case t
        completion-ignore-case t))

(use-package savehist
  :init
  (savehist-mode 1))

(use-package vertico
  :init
  (vertico-mode 1))

(use-package orderless
  :init
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides
        '((file (styles partial-completion)))))

(use-package marginalia
  :init
  (marginalia-mode 1))

(use-package consult
  :bind (("C-s" . consult-line)
         ("C-c s r" . consult-ripgrep)
         ("C-c s g" . consult-git-grep)
         ("C-c b" . consult-buffer)))

(provide 'core-ui)
