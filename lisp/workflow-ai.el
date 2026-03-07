;;; workflow-ai.el --- Optional AI helpers for workflow notes  -*- lexical-binding: t; -*-
;;
;; This file provides minimal, approval-friendly AI commands for workflow
;; notes, using the user's active gptel backend/model configuration.

(require 'org)
(require 'subr-x)

(declare-function gptel "gptel" (&optional arg))
(declare-function gptel-menu "gptel-transient" ())
(declare-function gptel-request "gptel-request"
                  (&optional prompt &rest args))

(defcustom workflow-ai-enabled nil
  "Enable workflow AI commands.

When nil, workflow AI commands signal a user error with setup guidance."
  :type 'boolean
  :group 'workflow)

(defcustom workflow-ai-max-context-chars 8000
  "Maximum number of characters from a note sent as AI context."
  :type 'integer
  :group 'workflow)

(defcustom workflow-ai-preview-buffer-name "*workflow-ai-preview*"
  "Buffer name used for AI preview output."
  :type 'string
  :group 'workflow)

(use-package gptel
  :commands (gptel gptel-menu gptel-request))

(defun workflow-ai--ensure-ready ()
  "Ensure workflow AI commands are enabled and gptel is available."
  (unless workflow-ai-enabled
    (user-error
     "Workflow AI is disabled. Set `workflow-ai-enabled' to non-nil to use AI commands"))
  (unless (require 'gptel nil t)
    (user-error "gptel is not available; install package `gptel' first"))
  (unless (fboundp 'gptel-request)
    (require 'gptel-request nil t))
  (unless (fboundp 'gptel-request)
    (user-error "gptel-request is unavailable; check your gptel installation")))

(defun workflow-ai--current-note-title ()
  "Return current note title or filename fallback." 
  (let* ((kw (assoc "TITLE" (org-collect-keywords '("TITLE"))))
         (title (car (cdr kw))))
    (if (and title (not (string-empty-p (string-trim title))))
        (string-trim title)
      (file-name-base (or (buffer-file-name) (buffer-name))))))

(defun workflow-ai--note-context ()
  "Build context payload from the current note buffer."
  (let* ((title (workflow-ai--current-note-title))
         (raw (buffer-substring-no-properties (point-min) (point-max)))
         (snippet (if (> (length raw) workflow-ai-max-context-chars)
                      (substring raw 0 workflow-ai-max-context-chars)
                    raw)))
    (format "Title: %s\n\nNote content:\n%s" title snippet)))

(defun workflow-ai--render-preview (heading content)
  "Render CONTENT under HEADING in the workflow AI preview buffer."
  (let ((buffer (get-buffer-create workflow-ai-preview-buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "%s\n\n" heading))
        (insert content)
        (goto-char (point-min))
        (view-mode 1)))
    (display-buffer buffer)))

(defun workflow-ai-chat (&optional choose-backend)
  "Open a gptel chat buffer.

With CHOOSE-BACKEND (prefix arg), open the gptel menu first so you can
pick backend/model for the session."
  (interactive "P")
  (workflow-ai--ensure-ready)
  (when (and choose-backend (fboundp 'gptel-menu))
    (call-interactively #'gptel-menu))
  (call-interactively #'gptel))

(defun workflow-ai-summarize-current-note (&optional choose-backend)
  "Request a concise AI summary for the current note and preview it.

With CHOOSE-BACKEND (prefix arg), open the gptel menu first so you can
pick backend/model for this request."
  (interactive "P")
  (workflow-ai--ensure-ready)
  (unless (derived-mode-p 'org-mode)
    (user-error "Current buffer is not an Org note"))
  (when (and choose-backend (fboundp 'gptel-menu))
    (call-interactively #'gptel-menu))
  (let* ((title (workflow-ai--current-note-title))
         (context (workflow-ai--note-context))
         (prompt
          (concat
           "Summarize the note below in 3 bullet points and propose 1 next action.\n"
           "Keep the output under 120 words.\n\n"
           context)))
    (message "workflow-ai: requesting summary for '%s'..." title)
    (gptel-request
     prompt
     :system
     "You are a concise assistant for personal workflow notes. Return plain text only."
     :callback
     (lambda (response info)
       (if (stringp response)
           (workflow-ai--render-preview
            (format "AI Summary: %s" title)
            response)
         (workflow-ai--render-preview
          (format "AI Summary Failed: %s" title)
          (format "Status: %s" (or (plist-get info :status) "Unknown error"))))))))

(provide 'workflow-ai)
