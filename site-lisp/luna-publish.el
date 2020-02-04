;;; luna-publish.el --- Publish blog      -*- lexical-binding: t; -*-

;; Author: Yuan Fu <casouri@gmail.com>

;;; This file is NOT part of GNU Emacs

;;; Commentary:
;;

;;; Code:
;;

(require 'luna-f)
(require 'subr-x)

(defun luna-publish-html-export (dir &optional force)
  "Export index.org to index.html in DIR if the latter is older.
If FORCE is non-nil, only export when org file is newer than html file."
  (let ((org-file (expand-file-name "index.org" dir))
        (html-file (expand-file-name "index.html" dir))
        (default-directory dir)) ; for relative links in org file
    (when (and (file-exists-p org-file)
               (or force (file-newer-than-file-p org-file html-file)))
      (with-current-buffer (find-file org-file)
        (org-html-export-to-html)
        (kill-buffer)))))

;;; RSS

(defun luna-publish-rss-export (link category-list dir &optional force)
  "Export index.html to css-item.xml in DIR if the latter is older.
If FORCE is non-nil, only export when org file is newer than html file.

LINK is the web link for the post in dir.
Categories in CATEGORY-LIST are strings."
  (let ((org-file (expand-file-name "index.org" dir))
        (rss-file (expand-file-name "css-item.xml" dir)))
    (when (file-exists-p org-file)
      (if (or force ; force export
              (not (file-exists-p rss-file)) ; rss doesn’t exist
              (file-newer-than-file-p org-file rss-file)) ; org newer
          (let* ((intro (or (string-remove-suffix
                             "\n"
                             (with-current-buffer (find-file org-file)
                               (org-element-map
                                   (org-element-parse-buffer)
                                   'plain-text #'identity
                                   nil t)))
                            "No intro."))
                 (html (with-current-buffer (find-file org-file)
                         (let ((org-html-style-default "")
                               (org-html-head "")
                               (org-html-head-extra "")
                               (org-html-postamble nil)
                               (org-html-head-include-scripts nil)
                               (org-export-with-toc nil)
                               (org-export-use-babel nil)
                               (org-html-htmlize-output-type nil))
                           ;; org-export-as doesn’t seem to respect above settings
                           ;; body only
                           (org-html-export-as-html nil nil nil t)
                           (buffer-substring-no-properties
                            1 (1+ (buffer-size))))))
                 (env (with-current-buffer (find-file org-file)
                        (org-export-get-environment)))
                 (date (let ((time (cadar (plist-get env :date))))
                         (format-time-string
                          "%a, %d %b %Y %H:%M:%S %z"
                          (encode-time
                           0
                           (or (plist-get time :minute-start) 0)
                           (or (plist-get time :hour-start)   0)
                           (or (plist-get time :day-start)    0)
                           (or (plist-get time :month-start)  0)
                           (or (plist-get time :year-start)   0)))))
                 (title (or (car (plist-get env :title))
                            "No title"))
                 (link (url-encode-url link)))
            (with-temp-buffer
              (insert (string-join
                       (list "<item>"
                             (format "<title>%s</title>" title)
                             (format "<link>%s</link>" link)
                             (format "<guid>%s</guid>" link)
                             ;; (format "<description>%s</description>" intro)
                             (format "<description><![CDATA[%s]]></description>\n" html)
                             (format "<pubDate>%s</pubDate>" date)
                             "</item>\n")
                       "\n"))
              (write-file rss-file)
              (buffer-substring-no-properties (point-min) (point-max))))
        ;; if not newer
        (luna-f-content rss-file)))))

(provide 'luna-publish)

;;; luna-publish.el ends here
