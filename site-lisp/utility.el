;;; utility.el --- Utilities      -*- lexical-binding: t; -*-

(require 'lunary)
(require 'luna-f)
(require 'cl-lib)
(require 'subr-x)

;;; Emacs 28 back port

(unless (boundp 'undo--last-change-was-undo-p)
  (defun undo--last-change-was-undo-p (undo-list)
    (while (and (consp undo-list) (eq (car undo-list) nil))
      (setq undo-list (cdr undo-list)))
    (gethash undo-list undo-equiv-table))

  (defun undo-redo (&optional arg)
    "Undo the last ARG undos."
    (interactive "*p")
    (cond
     ((not (undo--last-change-was-undo-p buffer-undo-list))
      (user-error "No undo to undo"))
     (t
      (let* ((ul buffer-undo-list)
             (new-ul
              (let ((undo-in-progress t))
                (while (and (consp ul) (eq (car ul) nil))
                  (setq ul (cdr ul)))
                (primitive-undo arg ul)))
             (new-pul (undo--last-change-was-undo-p new-ul)))
        (message "Redo%s" (if undo-in-region " in region" ""))
        (setq this-command 'undo)
        (setq pending-undo-list new-pul)
        (setq buffer-undo-list new-ul))))))

;;; Buffer

(defun luna-kill-other-buffer ()
  "Kill all other buffers (besides the current one).

If PROJECT-P (universal argument), kill only buffers that belong to the current
project."
  ;; copied from doom-emacs
  (interactive)
  (let ((buffers (buffer-list))
        (current-buffer (current-buffer)))
    (dolist (buf buffers)
      (unless (eq buf current-buffer)
        (luna-kill-buffer-and-window buf)))
    (when (called-interactively-p 'interactive)
      (message "Killed %s buffers" (length buffers)))))

(defun luna-kill-buffer-and-window (buffer)
  ;; copied from doom-emacs
  "Kill the buffer and delete all the windows it's displayed in."
  (dolist (window (get-buffer-window-list buffer))
    (unless (one-window-p t)
      (delete-window window)))
  (kill-buffer buffer))

(defun switch-buffer-same-major-mode ()
  "Switch buffer among those who have the same major mode as the current one."
  (interactive)
  (switch-to-buffer
   (completing-read
    "Buffer: "
    (mapcar #'buffer-name
            (cl-remove-if-not (lambda (buf)
                                (provided-mode-derived-p
                                 (buffer-local-value 'major-mode buf)
                                 major-mode))
                              (buffer-list))))))

(defun show-line-number ()
  "Show current line’s line number."
  (interactive)
  (message "Line %s" (1+ (current-line))))

(defun open-in-finder ()
  "Open ‘default-directory’ in Finder."
  (interactive)
  (shell-command-to-string (format "open %s" default-directory)))

(defun open-in-iterm ()
  "Open ‘default-directory’ iTerm."
  (interactive)
  (shell-command-to-string
   (format "open -a /Applications/iTerm.app %s" default-directory)))

;;; File

(defun luna-rename-file ()
  ;; https://stackoverflow.com/questions/384284/how-do-i-rename-an-open-file-in-emacs
  "Renames current buffer and file it is visiting."
  (interactive)
  (let* ((name (buffer-name))
         (filename (buffer-file-name))
         (basename (file-name-nondirectory filename)))
    (if (not (and filename (file-exists-p filename)))
        (error "Buffer '%s' is not visiting a file!" name)
      (let ((new-name (read-file-name "New name: " (file-name-directory filename) basename nil basename)))
        (if (get-buffer new-name)
            (error "A buffer named '%s' already exists!" new-name)
          (rename-file filename new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil)
          (message "File '%s' successfully renamed to '%s'"
                   name (file-name-nondirectory new-name)))))))

(defun luna-sudo-edit (&optional arg)
  "Edit currently visited file as root.

With a prefix ARG prompt for a file to visit.
Will also prompt for a file to visit if current
buffer is not visiting a file."
  (interactive "P")
  (if (or arg (not buffer-file-name))
      (find-file (concat "/sudo:root@localhost:"
                         (ido-read-file-name "Find file(as root): ")))
    (find-alternate-file (concat "/sudo:root@localhost:" buffer-file-name))))

(defun luna-find-file (&optional arg)
  "Find file. If called with ARG, find file in project."
  (interactive "p")
  (call-interactively
   (if (eq arg 4)
       #'project-find-file
     #'find-file)))

;;; Package mirror

(defvar luna-package-mirror-alist
  (let* ((no-ssl (and (memq system-type '(windows-nt ms-dos))
                      (not (gnutls-available-p))))
         (proto (if no-ssl "http" "https")))
    `(,(cons 'melpa
             `(,(cons "gnu"   (concat proto "://elpa.gnu.org/packages/"))
               ,(cons "melpa" (concat proto "://melpa.org/packages/"))))
      ,(cons 'melpa-mirror
             `(,(cons "gnu"   (concat proto "://elpa.gnu.org/packages/"))
               ,(cons "melpa" (concat proto "://www.mirrorservice.org/sites/melpa.org/packages/"))))
      ,(cons 'emacs-china
             `(,(cons "gnu"   (concat proto "://elpa.emacs-china.org/gnu/"))
               ,(cons "melpa" (concat proto "://elpa.emacs-china.org/melpa/"))))
      ,(cons 'netease
             `(,(cons "gnu"   (concat proto "://mirrors.163.com/elpa/gnu/"))
               ,(cons "melpa" (concat proto "://mirrors.163.com/elpa/melpa/"))))
      ,(cons 'tencent
             `(,(cons "gnu"   (concat proto "://mirrors.cloud.tencent.com/elpa/gnu/"))
               ,(cons "melpa" (concat proto "://mirrors.cloud.tencent.com/elpa/melpa/"))))
      ,(cons 'tuna
             `(,(cons "gnu"   (concat proto "://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/"))
               ,(cons "melpa" (concat proto "://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/"))))))
  "Each mirror can be used for ‘package-archives’.")

(defun luna-change-mirror (mirror)
  "Change mirror."
  (interactive (list (completing-read
                      "Mirror: "
                      (mapcar #'car luna-package-mirror-alist)
                      nil t)))
  (require 'package)
  (setq package-archives
        (alist-get mirror luna-package-mirror-alist))
  (package-refresh-contents))

;;; ENV

(defun luna-load-env ()
  "Load PATH and CPATH from a file."
  (interactive)
  (condition-case err
      (progn (load "~/.emacsenv")
             (setq exec-path (split-string (getenv "PATH") ":")))
    (error (message (error-message-string err)))))

(defun luna-set-env ()
  "Set PATH and CPATH."
  (interactive)
  (shell-command-to-string
   "source ~/.profile; ~/.emacs.d/site-lisp/setemacsenv"))

;;; Insert

(defvar luna-special-symbol-alist '(("(c)" . "©")
                                    ("tm" . "™")
                                    ("p" . " ")
                                    ("s" . "§")
                                    ("--" . "—") ; em dash
                                    ("-" . "–") ; en dash
                                    ("..." . "…")
                                    ("<" . "⃖")
                                    (">" . "⃗")
                                    ("^" . "ꜛ")
                                    ("v" . "ꜜ")
                                    ("<<" . "←")
                                    (">>" . "→")
                                    ("^^" . "↑")
                                    ("vv" . "↓")
                                    ("l" . "‘")
                                    ("r" . "’")
                                    ("ll" . "“")
                                    ("rr" . "”")
                                    (" " . " ") ; non-breaking space
                                    ("hand" . "☞"))
  ;; don’t use tab character because we use that for splitting
  ;; in ‘luna-insert-special-symbol’
  "Alist used by `luna-insert-special-symbol'.")

(defun luna-insert-special-symbol (surname)
  "Insert special symbol at point, SURNAME is used to search for symbol.
E.g. SURNAME (c) to symbol ©."
  (interactive (list (car (split-string
                           (completing-read
                            "MAbbrev: "
                            (mapcar (lambda (c)
                                      (format "%s\t%s" (car c) (cdr c)))
                                    luna-special-symbol-alist))
                           "\t"))))
  (insert (alist-get surname luna-special-symbol-alist "" nil #'equal)))

(defun luna-make-accent-fn (name)
  "Return a command that insert “COMBINDING NAME” unicode char."
  (lambda () (interactive)
    (insert (char-from-name (concat "COMBINING " name)))))

(global-set-key (kbd "C-x 9 -") (luna-make-accent-fn "MACRON"))

;;; Navigation

(defvar luna-scroll-map (let ((map (make-sparse-keymap)))
                          (define-key map (kbd "n") #'luna-scroll-down-reserve-point)
                          (define-key map (kbd "p") #'luna-scroll-up-reserve-point)
                          map)
  "Transient map for `luna-scroll-mode'.")

(defun luna-scroll-down-reserve-point ()
  (interactive)
  (scroll-up 2)
  (next-line 2)
  (set-transient-map luna-scroll-map t))

(defun luna-scroll-up-reserve-point ()
  (interactive)
  (scroll-down 2)
  (next-line -2)
  (set-transient-map luna-scroll-map t))

(defun up-list-backward ()
  (interactive)
  (up-list -1))

;;; Auto insert

(defvar luna-autoinsert-template (luna-f-join user-emacs-directory
                                              "star"
                                              "autoinsert-template.el")
  "The template file.")

(defun luna-autoinsert (description)
  "Autoinsert what auto-insert inserts."
  (interactive "MDescription: ")
  (let* ((filename (file-name-nondirectory (buffer-file-name)))
         (year (format-time-string "%Y"))
         (feature (file-name-base (buffer-file-name)))
         (template (luna-f-content luna-autoinsert-template)))
    (insert (format template
                    filename description feature filename))))

;;; smart-delete

(defun luna-hungry-delete-advice (&rest _)
  (catch 'end
    (let ((p (point)) beg end newline-count)
      (skip-chars-backward " \t")
      (if (not (eq (char-before) ?\n))
          (throw 'end nil))
      (skip-chars-backward " \t\n")
      (setq beg (point))
      (goto-char p)
      (skip-chars-forward " \t\n")
      (setq end (point))
      (setq newline-count
            (cl-count ?\n (buffer-substring-no-properties beg end)))
      (delete-region beg end)
      (cond ((eq (char-after) ?})
             (insert "\n")
             (indent-for-tab-command))
            ((eq (char-after) ?\))
             nil)
            ((> newline-count 1)
             (insert "\n")
             (indent-for-tab-command))
            ((> newline-count 0)
             (insert " "))))))

;;; Cheat sheet

(defvar cheatsheet-file-dir (expand-file-name "cheatsheet"
                                              user-emacs-directory)
  "Under where you put the cheat sheets.")

(defvar cheatsheet-display-fn (lambda (txt) (message "%s" txt))
  "Function for displaying cheat sheet.")

(defun cheatsheet-display ()
  "Display cheat sheet for this major mode."
  (interactive)
  (let* ((mode-name (symbol-name major-mode))
         (file-path (expand-file-name mode-name cheatsheet-file-dir)))
    (condition-case nil
        (funcall cheatsheet-display-fn (luna-f-content file-path))
      (error (user-error "Cannot find cheat sheet for %s" major-mode)))))

(defalias 'helpme 'cheatsheet-display)

;;; Toggle dash

(defvar dash-underscore-mode-map (make-sparse-keymap))

(define-minor-mode dash-underscore-mode
  "Remaps “-” to “_”."
  :lighter " (-_)"
  :keymap 'dash-underscore-mode-map
  (if dash-underscore-mode
      ;; not sure how does remap works for swapping
      (progn  (define-key dash-underscore-mode-map "-"
                (lambda () (interactive) (insert "_")))
              (define-key dash-underscore-mode-map "_"
                (lambda () (interactive) (insert "-"))))
    (setq dash-underscore-mode-map (make-sparse-keymap))))

;;; Customize

(defun kill-emacs-no-save-customize ()
  "Kill Emacs and don’t save customization."
  (interactive)
  (remove-hook 'kill-emacs-hook #'customize-save-customized)
  (save-buffers-kill-emacs))

;;; ChangeLog

(defun copy-change-log ()
  (interactive)
  (let* ((fileset (cadr (vc-deduce-fileset t)))
         (changelog (cl-loop for file in fileset
                             do (progn (find-file file)
                                       (add-change-log-entry))
                             collect (buffer-string))))
    (when (string-match-p "changes to" (buffer-name)) (kill-buffer))
    (with-temp-buffer
      (dolist (log changelog)
        (insert log))
      (kill-ring-save (point-min) (point-max)))))

;;; Variable pitch font in code

(define-minor-mode global-variable-prog-mode
  "Global ‘variable-prog-mode’."
  :lighter ""
  :global t
  (if global-variable-prog-mode
      (progn (dolist (buf (buffer-list))
               (with-current-buffer buf
                 (when (derived-mode-p 'prog-mode)
                   (variable-prog-mode))))
             (add-hook 'prog-mode-hook #'variable-prog-mode))
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (derived-mode-p 'prog-mode)
          (variable-prog-mode -1))))
    (remove-hook 'prog-mode-hook #'variable-prog-mode)))

(define-minor-mode variable-prog-mode
  "Variable-pitch font in code."
  :lighter ""
  (if variable-prog-mode
      (progn (variable-pitch-mode)
             (font-lock-add-keywords nil '(("^ *" . 'fixed-pitch)
                                           ("[()'\"]" . 'fixed-pitch))))
    (variable-pitch-mode -1)
    (font-lock-remove-keywords nil '(("^ *" . 'fixed-pitch)
                                     ("[()'\"]" . 'fixed-pitch))))
  (font-lock-mode -1)
  (font-lock-mode))

;;; Provide

(provide 'utility)

;;; utility.el ends here

