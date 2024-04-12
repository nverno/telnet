;;; telnet-ext.el --- Extended telnet -*- lexical-binding: t; -*-

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/telnet-ext
;; Version: 0.0.1
;; Package-Requires: ((emacs "27.1"))
;; Created: 12 April 2024
;; Keywords: unix, comm, telnet

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;; Code:

(require 'telnet)


(defcustom telnet-ext-escape-key "C-]"
  "Escape character in telnet."
  :group 'telnet-ext
  :type 'string)

(defvar telnet-ext-commands
  '("help" "close" "logout" "display" "mode" "open"
    "quit" "send" "set" "unset" "status" "toggle" "slc" "z" "environ")
  "Top-level telnet commands.")

(defvar telnet-ext-font-lock-keywords
  `((,(rx-to-string
       `(seq bol (* (syntax whitespace)) bow (or ,@telnet-ext-commands) eow))
     . font-lock-keyword-face)
    (,(rx-to-string
       `(seq (regexp ,telnet-prompt-pattern) (* (syntax whitespace))
             bow (group (or ,@telnet-ext-commands)) eow))
     (1 font-lock-keyword-face)))
  "Font-locking for telnet commands.")

(defun telnet-ext-completion-at-point ()
  "Simple `completion-at-point' for top-level telnet commands."
  (when (comint-after-pmark-p)
    (let ((end (point))
          (beg (save-excursion
                 (goto-char (comint-line-beginning-position))
                 (skip-syntax-forward " " (line-end-position))
                 (point))))
      (when (and beg (save-excursion
                       (goto-char beg)
                       (looking-back telnet-prompt-pattern (line-beginning-position))))
        (list beg end
              (completion-table-with-cache
               (lambda (_s) telnet-ext-commands))
              :exclusive 'no)))))

(defun telnet-ext-send-escape ()
  "Send escape character to telnet."
  (interactive)
  (process-send-string nil (kbd telnet-ext-escape-key)))

(defvar-keymap telnet-ext-mode-map
  :parent telnet-mode-map
  "TAB" #'completion-at-point
  telnet-ext-escape-key #'telnet-ext-send-escape)

;;; Telnet State
;; When talking to telnet, process doesn't echo
;; When talking to remote, process echoes
(defvar-local telnet-ext--remote-p nil)

(defun telnet-ext--preoutput-filter (orig-fn proc string)
  "Filter run before `telnet-filter'."
  (setq-local telnet-remote-echoes 
              (not (string-match-p (concat telnet-prompt-pattern "$") string))
              telnet-ext--remote-p nil)
  (funcall orig-fn proc string))

(advice-add 'telnet-filter :around #'telnet-ext--preoutput-filter)

(defun telnet-ext--input-filter (string)
  "Filter input STRING in `comint-input-filter-functions'."
  (setq-local telnet-remote-echoes (or telnet-remote-echoes telnet-ext--remote-p))
  (when (string-match-p "\\s-+" string)
    (setq-local telnet-ext--remote-p (null telnet-ext--remote-p)))
  string)

;;;###autoload
(define-derived-mode telnet-ext-mode comint-mode "Telnet"
  "Major mode for telnet.
This is a replacement for `telnet-mode'.

Commands:
\\<telnet-mode-map>"
  :abbrev-table telnet-mode-abbrev-table
  :syntax-table telnet-mode-syntax-table
  (setq-local revert-buffer-function #'telnet-revert-buffer
              window-point-insertion-type t
              comint-prompt-regexp telnet-prompt-pattern
              comint-prompt-read-only t
              comint-use-prompt-regexp t
              comint-input-filter-functions '(telnet-ext--input-filter)
              ;; comint-preoutput-filter-functions '(telnet-ext--preoutput-filter)
              ;; Make `comint-previous-prompt'/`comint-next-prompt' work better
              paragraph-start telnet-prompt-pattern
              paragraph-separate (concat "\n" telnet-prompt-pattern)
              completion-at-point-functions '(telnet-ext-completion-at-point)
              font-lock-defaults '(telnet-ext-font-lock-keywords)))

;;;###autoload
(advice-add 'telnet-mode :override #'telnet-ext-mode)

(provide 'telnet-ext)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; telnet-ext.el ends here
