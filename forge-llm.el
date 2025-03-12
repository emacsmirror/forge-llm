(require 'forge)

;;;###autoload
(defun forge-llm-hello ()
  "Display pull request branch information and show git diff in a Forge PR buffer."
  (interactive)
  (if (not (derived-mode-p 'forge-post-mode))
      (message "Not in a Forge pull request buffer")
    (let ((head (and (boundp 'forge--buffer-head-branch) forge--buffer-head-branch))
          (base (and (boundp 'forge--buffer-base-branch) forge--buffer-base-branch)))
      (if (and head base)
          (let* ((default-directory (file-name-directory
                                     (directory-file-name
                                      (file-name-directory
                                       (or buffer-file-name default-directory)))))
                 (pr-desc (format "Pull Request: %s → %s" head base))
                 (repo-root (locate-dominating-file default-directory ".git")))
            ;; First show the PR branches in the message area
            (message "%s" pr-desc)

            ;; Now create a buffer with the git diff
            (when repo-root
              (let ((diff-command (format "git diff %s..%s" base head))
                    (buffer (get-buffer-create "*forge-llm-diff*")))
                (with-current-buffer buffer
                  (setq buffer-read-only nil)
                  (erase-buffer)
                  (insert (format "Diff for %s\n\n" pr-desc))
                  (let ((default-directory repo-root))
                    (call-process-shell-command diff-command nil buffer))
                  (diff-mode)
                  (setq buffer-read-only t)
                  (goto-char (point-min)))
                (display-buffer buffer))))
        (message "Branch information not available")))))

;;;###autoload
(defun forge-llm-debug ()
  "Debug function to show all relevant forge and magit variables."
  (interactive)
  (with-output-to-temp-buffer "*forge-llm-debug*"
    (let ((vars '()))
      ;; Collect global variables with forge or magit in name
      (mapatoms
       (lambda (sym)
         (when (and (boundp sym)
                    (not (keywordp sym))
                    (symbolp sym)
                    (or (string-match-p "forge" (symbol-name sym))
                        (string-match-p "magit" (symbol-name sym))))
           (push sym vars))))

      ;; Sort and print global variables
      (setq vars (sort vars (lambda (a b) (string< (symbol-name a) (symbol-name b)))))
      (princ "=== Global Variables ===\n\n")
      (dolist (var vars)
        (princ (format "%s: %S\n\n" var (symbol-value var))))

      ;; Print local variables
      (princ "\n\n=== Buffer-Local Variables ===\n\n")
      (dolist (var (buffer-local-variables))
        (when (and (symbolp (car var))
                   (or (string-match-p "forge" (symbol-name (car var)))
                       (string-match-p "magit" (symbol-name (car var)))))
          (princ (format "%s: %S\n\n" (car var) (cdr var))))))))

;;;###autoload
(defun forge-llm-setup ()
  "Set up forge-llm integration with Forge's new-pullreq buffer."
  (interactive)
  (add-hook 'forge-post-mode-hook #'forge-llm-setup-pullreq-hook)
  (message "forge-llm has been set up successfully"))

(defun forge-llm-setup-pullreq-hook ()
  "Hook function to set up forge-llm in a new-pullreq buffer."
  ;; Only add our keybinding if this is a pull request post
  (when (and buffer-file-name
             (string-match-p "new-pullreq" buffer-file-name))
    (local-set-key (kbd "C-c C-l") #'forge-llm-hello)
    (local-set-key (kbd "C-c C-d") #'forge-llm-debug)))

(provide 'forge-llm)
