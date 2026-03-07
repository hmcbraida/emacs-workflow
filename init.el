;;; init.el --- Load modular workflow config  -*- lexical-binding: t; -*-
;;
;; This file is the top-level orchestrator. It adds the local module
;; directory to `load-path' and then loads each module in dependency order.

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(require 'core-packages)
(require 'core-ui)
(require 'org-core)
(require 'org-roam-config)
(require 'workflow-git-sync)
(require 'workflow-lifecycle)
(require 'workflow-triage)
(require 'workflow-search)
(require 'workflow-media)
(require 'workflow-keys)

(provide 'init)
