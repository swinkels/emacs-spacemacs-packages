;;; orgox.el --- Convert org-mode file to one suited for ox-hugo  -*- lexical-binding: t; -*-

;; Copyright (C) 2025  Pieter Swinkels

;; Author: Pieter Swinkels <swinkels.pieter@yahoo.com>
;; Maintainer: Pieter Swinkels <swinkels.pieter@yahoo.com>
;; URL: https://github.com/swinkels/orgox
;; Package-Version: 20251230.121351
;; Version: 0.1.0
;; Package-Requires: ((emacs "26.3") (f "0.20.0") (ox-hugo "0.12.2"))
;; Keywords: tools ox-hugo

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides functions to convert the org-mode files that the author
;; uses to write their notes, to files that are suitable for publishing with
;; ox-hugo.

;;; Code:

(require 'f)
(require 'ox-hugo)

;; The code in this package uses the following terminology.
;;
;; A "note" is an org-mode file that adheres to the certain conventions. First,
;; its filename should specify the date of the note as YYYYMMDD.org. Second, its
;; top-level headline should specify the title of the note. All other headlines
;; in the note should be one or more levels below the top-level headline. Third,
;; a note can refer to local files. These local files are either other notes or
;; files that are only relevant for the content of the note itself. The latter
;; are called "note assets", for example images and code snippets. Note assets
;; should be placed in a subdirectory with the same name (date) as the note
;; filename (excluding its extension ".org"), next to the note.
;;
;; An "ox-hugo file" is an org-mode file that contains the content of a note but
;; suitable for publishing with ox-hugo. orgox functions extract information
;; from the note and its filename and stores it as org-mode properties that
;; ox-hugo recognizes. ox-hugo files have the extension "ox-hugo.org".
;;
;; To export a note means to create the appropriate ox-hugo file for it. To
;; publish a note means to create the appropriate ox-hugo file and convert that
;; file to markdown.
;;
;; A variable whose name ends with "-file" is an absolute or relative path to a
;; file, with "-dir" an absolute or relative path to a directory, with
;; "-filename" a filename and with "-dirname" a directory name.

;;;; Public API

(defgroup orgox nil
  "Convert Org file to one suitable for publishing by ox-hugo."
  :group 'Tools)

(defcustom orgox-hugo-site-directory nil
  "Directory of ox-hugo site."
  :type 'directory :group 'orgox)

(defcustom orgox-base-url-for-note-asset nil
  "URL to use for note assets that should not be converted.

ox-hugo converts each link to an Org file as if that Org file is another
note to publish.  This results in a broken link if (1) the target is an
Org file that is a note asset or (2) the target is a note directory.  To
avoid that, orgox replaces a link with the URL to the note asset or
directory in the online note repository."
  :type 'string :group 'orgox)

;;;###autoload
(defun orgox-export-current-buffer ()
  "Export the current buffer, which should hold a note, to an ox-hugo file."
  (interactive)
  (orgox--export-note-buffer (current-buffer)))

;;;###autoload
(defun orgox-publish-current-buffer ()
  "Publish the current buffer, which should hold a note, to an ox-hugo file."
  (interactive)
  (let ((ox-hugo-file (orgox--export-to-ox-hugo-file (current-buffer))))
    (with-current-buffer (find-file-noselect ox-hugo-file)
      (org-hugo-export-wim-to-md :all-subtrees))))

(defun orgox-export-note-file (note-file)
  "Export NOTE-FILE, which should refer to a note, to an ox-hugo file."
  (orgox--export-note-buffer (find-file-noselect note-file)))

;;;; Implementation

(defun orgox--export-note-buffer (note-buffer)
  "Export NOTE-BUFFER, which should contain a note, to an ox-hugo file.
Before this function exports the note buffer, it validates several
prerequisites of the export.  For example, it checks that the variables
required for an export are configured correctly.  Should that validation
fail, this function raises an error.

This function is really suited to do the grunt-work for other public
functions."

  (unless orgox-hugo-site-directory
    (error "Hugo site directory is not configured"))

  (unless (f-directory-p orgox-hugo-site-directory)
    (error (format "Hugo site directory %s does not exist" orgox-hugo-site-directory)))

  (let ((content-dir (orgox--get-ox-hugo-content-dir)))
    (when (f-exists-p content-dir)
      (unless (and (f-directory-p content-dir) (f-writable-p content-dir))
        (error
         (format
          "Hugo subdirectory for org-mode content %s should be a writable directory"
          content-dir)))))

  (unless org-hugo-default-static-subdirectory-for-externals
    (error "Hugo subdirectory for static externals is not configured"))

  (let ((static-externals-dir (orgox--get-ox-hugo-static-externals-dir)))
    (when (f-exists-p static-externals-dir)
      (unless (and (f-directory-p static-externals-dir) (f-writable-p static-externals-dir))
        (error
         (format
          "Hugo subdirectory for static externals %s should be a writable directory"
          static-externals-dir)))))

  (let* ((note-buffer-name (buffer-name note-buffer))
         (date-elements (orgox--extract-date-elements note-buffer-name)))

    (unless date-elements
      (error (format "Unable to extract date elements from \"%s\"" note-buffer-name)))

    ;; create the directories to hold the org-mode content and the static files
    (f-mkdir-full-path (orgox--get-ox-hugo-content-dir))
    (f-mkdir-full-path (orgox--get-ox-hugo-static-externals-dir))

    (orgox--export-to-ox-hugo-file note-buffer)
    (orgox--sync-note-assets (buffer-file-name note-buffer))))

(defun orgox--export-to-ox-hugo-file (note-buffer)
  "Export NOTE-BUFFER, which should contain a note, to an ox-hugo file.
Where `orgox--export-note-buffer' validates that all preconditions to
convert the contents of NOTE-BUFFER are in place, this function does the
actual conversion."
  (let* ((note-buffer-name (buffer-name note-buffer))
         (date-elements (orgox--extract-date-elements note-buffer-name))
         (ox-hugo-file-name (orgox--get-ox-hugo-file-name note-buffer-name))
         (ox-hugo-file (f-join (orgox--get-ox-hugo-content-dir) ox-hugo-file-name)))
    (with-current-buffer (find-file-noselect ox-hugo-file)
      (erase-buffer)
      (insert-buffer-substring note-buffer)

      (goto-char (point-min))
      (insert "#+HUGO_BASE_DIR: ../\n")
      (insert (format "#+HUGO_SECTION: %s\n" (orgox--as-date-sections date-elements)))
      (insert (format "#+HUGO_SLUG: %s\n\n"
                      (save-excursion
                        ;; let the first headline provide the title
                        (goto-char (point-min))
                        (org-next-visible-heading 1)
                        (orgox--slug-for-current-heading))))

      ;; let the first headline provide the title
      (goto-char (point-min))
      (org-next-visible-heading 1)
      (org-set-property "EXPORT_FILE_NAME" (orgox--as-hugo-filename date-elements))
      (org-set-property "EXPORT_DATE" (orgox--as-date date-elements))

      (orgox--update-local-links)

      (save-buffer))))

(defun orgox--get-ox-hugo-file-name (note-buffer-name)
  "Return the ox-hugo filename for the given NOTE-BUFFER-NAME.
The ox-hugo filename is derived from the buffer name by replacing its
extension with '.ox-hugo.org'."
  (concat (f-no-ext note-buffer-name) ".ox-hugo.org"))

(defun orgox--extract-date-elements (buffer-name)
  "Return the date elements from BUFFER-NAME.
If BUFFER-NAME has the format \"YYYYMMDD.org\", the date elements is the
list of strings (YYYY MM DD).  If BUFFER-NAME has another format, this
function returns nil."
  (if (string-match-p "^20[[:digit:]]\\{6\\}$" (f-no-ext buffer-name))
      (list
       (substring buffer-name 0 4)
       (substring buffer-name 4 6)
       (substring buffer-name 6 8))
    nil))

(defun orgox--as-date-sections (date-elements)
  "Return the Hugo section string for DATE-ELEMENTS.
The string returned has format `org-hugo-section' concatenated with
\"/YYYY/MM/DD\".  `org-hugo-section' is the default section for Hugo
posts."
  (format "%s/%s/%s/%s"
          org-hugo-section
          (nth 0 date-elements)
          (nth 1 date-elements)
          (nth 2 date-elements)))

(defun orgox--as-date (date-elements)
  "Return the date string for DATE-ELEMENTS.
The string returned has format \"YYYY-MM-DD\"."
  (format "%s-%s-%s"
          (nth 0 date-elements)
          (nth 1 date-elements)
          (nth 2 date-elements)))

(defun orgox--as-hugo-filename (date-elements)
  "Return the Hugo filenmae string for DATE-ELEMENTS.
The string returned has format \"YYYYMMDD.md\"."
  (format "%s%s%s.md"
          (nth 0 date-elements)
          (nth 1 date-elements)
          (nth 2 date-elements)))

(defun orgox--update-local-links ()
  "Update links to other notes and note files.

ox-hugo automatically converts links to other files.  This works nicely
for other notes, but not for links to note directories and their
contents.  This function updates these links in the current buffer so
they work in the exported side.

This funcion finds each link that is formatted like

   [[<link target>]

and replace the link target by one that is suitable for export.
The replacement can be equal to the original link target if
ox-hugo supports the latter out-of-the-box.  For details, see
function `orgox-convert-link'.

The current function works and modifies the current buffer.  It
preserves the location of point."
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "\\[\\[\\([^]]*\\)]" nil t)
      (let* ((link (match-string 1))
             (new-link (save-match-data (orgox--convert-link link))))
        (replace-match new-link t t nil 1)))))

(defun orgox--convert-link (link)
  "Return a version of LINK that is suitable for export.
If LINK is a link to a note asset that is an Org file or to a note
directory, this function returns the link to its counterpart in the
online note repository.  If LINK is a link to a note asset that is not
an Org file, it returns a link to the asset in the static part of the
site.  In all other cases this function returns LINK."
  (if (string-match "^\\(file:\\)?\\(../\\)?\\(20[[:digit:]]\\{6\\}\\)$" link)
      (let* ((name (match-string 3 link))
             (date-elements (orgox--extract-date-elements name)))
        (format "%s/%s/%s/%s"
                orgox-base-url-for-note-asset
                (nth 0 date-elements)
                (nth 1 date-elements)
                name))
    (if (string-match "^\\(file:\\)?\\(../[[:digit:]]\\{2\\}/\\)?\\(20[[:digit:]]\\{6\\}\\)$" link)
        (let* ((name (match-string 3 link))
               (date-elements (orgox--extract-date-elements name)))
          (format "%s/%s/%s/%s"
                  orgox-base-url-for-note-asset
                  (nth 0 date-elements)
                  (nth 1 date-elements)
                  name))
      (if (string-match "^\\(file:\\)?\\(../../[[:digit:]]\\{4\\}/[[:digit:]]\\{2\\}/\\)?\\(20[[:digit:]]\\{6\\}\\)$" link)
          (let* ((name (match-string 3 link))
                 (date-elements (orgox--extract-date-elements name)))
            (format "%s/%s/%s/%s"
                    orgox-base-url-for-note-asset
                    (nth 0 date-elements)
                    (nth 1 date-elements)
                    name))
        (if (string-match "^\\(file:\\)?\\(../\\)?\\(20[[:digit:]]\\{6\\}\\)/\\(.*\\)$" link)
            (let* ((note-dir-name (match-string 3 link))
                   (note-dir-file (match-string 4 link))
                   (date-elements (orgox--extract-date-elements note-dir-name)))
              (if (string= (f-ext link) "org")
                  (format "%s/%s/%s/%s/%s"
                          orgox-base-url-for-note-asset
                          (nth 0 date-elements)
                          (nth 1 date-elements)
                          note-dir-name
                          note-dir-file)
                (format "/%s/%s" note-dir-name note-dir-file)))
          link)))))

(defun orgox--extract-slug (note-file)
  "Return the slug from the first headline of a NOTE-FILE."
  (with-current-buffer (find-file-noselect note-file)
    (org-next-visible-heading 1)
    (orgox--slug-for-current-heading)))

(defun orgox--slug-for-current-heading ()
  "Return the slug from the current headline.
The slug is created by converting the headline to lowercase and replacing
spaces with hyphens."
  (when (looking-at org-complex-heading-regexp)
    (let ((heading (nth 4 (org-heading-components))))
      (string-replace " " "-" (downcase heading)))))

(defun orgox--sync-note-assets (note-file)
  "Sync the assets of NOTE-FILE.
This function syncs the note assets directory to the directory that
holds the static files of the site.  If the given note does not have an
asset directory, this function does nothing."
  (let ((note-dir (f-no-ext note-file)))
    (when (f-directory-p note-dir)
      (orgox--one-way-sync note-dir (orgox--get-ox-hugo-static-externals-dir)))))

(defun orgox--one-way-sync (src-dir dest-dir)
  "Sync SRC-DIR to DEST-DIR using rsync.
Make sure the destination directory exists; rsync will fail otherwise."
  (f-mkdir-full-path dest-dir)
  (call-process "rsync" nil "orgox-process" nil "-Cavz" src-dir dest-dir))

(defun orgox--get-ox-hugo-static-externals-dir ()
  "Return the absolute path to the directory for static externals.
This is typically the \"static\" subdirectory of the Hugo site."
  (f-join orgox-hugo-site-directory "static"))

(defun orgox--get-ox-hugo-content-dir ()
  "Return the absolute path to the directory for ox-hugo content.
This is typically the \"content-org\" subdirectory of the Hugo site."
  (f-join orgox-hugo-site-directory "content-org"))

(provide 'orgox)

;;; orgox.el ends here
