;;; core-packages.el --- Package bootstrap and install policy  -*- lexical-binding: t; -*-
;;
;; This file initializes package archives, bootstraps `use-package', and
;; defines package installation defaults used by all other modules.

(require 'package)

(setq package-archives
      '(("gnu" . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa" . "https://melpa.org/packages/")))

(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)

(setq use-package-always-ensure t
      use-package-expand-minimally t
      use-package-compute-statistics t)

(provide 'core-packages)
