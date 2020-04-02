;;; wiring.el --- wiring stuff

;; Copyright (C) 2013, 2014, 2019, 2020  John Sturdy

;; Author: John Sturdy <john.sturdy@citrix.com>
;; Keywords: 

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; 

;;; Code:

(require 'cl)

(defvar wiring-connection-block-order
  '(("NEAR_WING" . 1)
    ("BULK_NEAR" . 2)
    ("BODY" . 3)
    ("BONN" . 4)
    ("GPS" . 5)				; was 25 (not used), FB_X was here
    ("OFF_WING" . 6)
    ("CONS_A" . 7)			; was 15 (2.7), SC_B was here
    ("CONS_B" . 8)			; was 16 (2.8), SC_A was here

    ("DB_B" . 9)
    ("DB_A" . 10)
    ("BATT" . 11)
    ("NEAR_REAR" . 12)
    ("FRONT_SKT" . 13)			; new, FB_N was here
    ("PEDALS" . 14)
    ("SC_A". 15)			; was 8 (1.8), CONS_B was here
    ("SC_B" . 16)			; was 7 (1.7), CONS_A was here

    ("ENG_A" . 17)
    ("ENG_B" . 18)
    ("ELEC_MOTOR" . 19)
    ("OFF_REAR" . 20)
    ("UP_OFF_A" . 21)
    ("UP_OFF_B" . 22)
    ("UP_NEAR_A" . 23)
    ("UP_NEAR_B" . 24)

    ("FB_X" . 25)
    ("FB_N" . 26)
    ("FB_O" . 27)
    ))

(defun wiring-connection-block (a)
  "Return which block A is in."
  (cdr (assoc (if (string-match "\\([A-Z_]+\\)_[1-8]" a)
		  (match-string 1 a)
		nil)
	      wiring-connection-block-order)))

(defvar wiring-connection-file
   (substitute-in-file-name "$VEHICLES/Marmalade/wiring.org")
   "The file defining the connections.")

(defun add-colour-coding (connections)
  "Add colour information to CONNECTIONS."
  (interactive (list nil))
  (save-excursion
    (find-file wiring-connection-file)
    (goto-char (point-min))
    (when (search-forward "*** Hub colour coding" (point-max) t)
      (search-forward "--+--")
      (let* ((end (org-table-end))
	     (begin (progn (goto-char end) (org-table-begin)))
	     (colours nil))
	(message "Colour table %S..%S" begin end)
	(goto-char begin)
	(while (re-search-forward "^\\s-+|\\s-+\\([a-z][^|]+?\\)\\s-+|\\s-+\\([a-z].+?\\)\\s-+|.*$" end t)
	  (push (cons (match-string-no-properties 1) (match-string-no-properties 2))
		colours))
	(dolist (connection connections)
	  (let ((pair (assoc (car connection)
			     colours)))
	    (when pair
	      (rplaca connection (format "%s (%s)"
					 (car connection)
					 (cdr pair))))))))))

(defun wiring-connection-table (&optional sort-by-count)
  "Make the wiring connection table.
Optional argument SORT-BY-COUNT is whether to sort by count."
  (interactive "P")
  (find-file wiring-connection-file)
  (let ((pattern (concat  "^\\s-+| \\([A-Z0-9_]+_[A-Z0-9_]+\\)"
			  ;; "\\(.+\\)"
			  "\\s-+| \\([A-Za-z0-9 ]+?\\)\\s-+\\(([A-Za-z0-9 ]+)\\s-+\\)?|"
			  )))
    (save-excursion
      (goto-char (point-min))
      (let ((connections nil))
	(while (re-search-forward pattern (point-max) t)
	  ;; (message "got %S" (match-string-no-properties 0))
	  (let* ((pin (match-string-no-properties 1))
		 (connection (downcase (match-string-no-properties 2)))
		 (conn-pins-holder (assoc connection connections)))
	    ;; (message "%s::%s::%s" connection pin (match-string-no-properties 3))
	    (if (null conn-pins-holder)
		(push (list connection pin)
		      connections)
	      (push pin (cdr conn-pins-holder)))))
	(add-colour-coding connections)
	(with-output-to-temp-buffer "*Connections*"
	  (let ((conn-format
		 (format "%% %ds: %%s\n" (reduce 'max (mapcar 'length (mapcar 'car connections))))))
	    (setq connections (remove-if #'(lambda (a) (equal (car a) "unused"))
					 connections))
	    (princ (format "%d connections:\n" (length connections)))
	    (dolist (conn (sort connections
				(if sort-by-count
				    #'(lambda (a b)
                                        (let ((an (length (cdr a)))
                                              (bn (length (cdr b))))
                                          (cond
                                           ((> an bn) t)
                                           ((< an bn) nil)
                                           (t (string< (car a) (car b))))))
				  #'(lambda (a b)
                                      (string< (car a) (car b))))))
	      (princ (format conn-format
			     (car conn)
			     (mapconcat 'downcase
					(mapcar #'(lambda (pin)
                                                    (let ((block (wiring-connection-block pin)))
                                                      (if block
                                                          (format "%s(%d,%d)"
                                                                  pin
                                                                  (wiring-connection-block-row block)
                                                                  (wiring-connection-block-column block))
                                                        pin)))
						(sort (remove-duplicates (cdr conn)
									 :test 'equal)
						      #'(lambda (a b)
                                                          (let ((a-rank (wiring-connection-block a))
                                                                (b-rank (wiring-connection-block b)))
                                                            (if (and a-rank b-rank)
                                                                (< a-rank b-rank)
                                                              (string< a b))))))
					", "))))))))))

(defun wiring-connection-block-row (block)
  "Return which row BLOCK is in."
  (1+ (/ (1- block) 8)))

(defun wiring-connection-block-column (block)
  "Return which column BLOCK is in."
  (1+ (% (1- block) 8)))

(defun wiring-connection-block-table (direction)
  "Draw one block table with DIRECTION function."
      (let* ((max-width (apply 'max (mapcar 'length (mapcar 'car wiring-connection-block-order))))
	   (cell-format (format "| %% -%ds " max-width))
	   (cell-top-format (make-string max-width ?-))
	   (row-top (concat "+--"
			    (mapconcat 'identity (make-vector 8 cell-top-format) "+--")
			    "+\n")))
      (princ row-top)
      (dotimes (y 3)
	(dotimes (x 8)
	  (let* ((block (+ (* y 8)
			   (1+ (funcall direction x))))
		 (cell-name (car (rassoc block wiring-connection-block-order))))
	    (princ (format cell-format cell-name))))
	(princ "|\n")
	(princ row-top))))

(defun wiring-connection-block-tables ()
  "Make connection block tables."
  (interactive)
  (with-output-to-temp-buffer "*Block tables*"
    (princ "From front:\n\n")
    (wiring-connection-block-table 'identity)
    (princ "\n\nFrom back:\n\n")
    (wiring-connection-block-table #'(lambda (n) (- 7 n)))))

(defun wiring-jump-to-definition ()
  "Jump to the definition of a symbol."
  (interactive)
  (let ((connection (symbol-name (symbol-at-point)))
	(window (get-buffer-window (find-buffer-visiting wiring-connection-file))))
    (if window
	(select-window window)
      (find-file-other-window wiring-connection-file))
    (let ((old (point)))
      (goto-char (point-min))
      (unless (search-forward connection (point-max) t)
	(goto-char old)))))

(defun wiring-next-connection ()
  "Move to the next connection."
  (interactive)
  (search-forward ")")
  (forward-word))

(global-set-key [ f3 ] 'wiring-next-connection)
(global-set-key [ f4 ] 'wiring-jump-to-definition)

(defun wiring-simple-emacs-setup ()
  "A simple setup for doing wiring stuff in an emacs without my full .emacs."
  (interactive)
  (require 'org)
  (add-to-list 'org-modules 'org-agenda)
  (org-load-modules-maybe t)
  (setq wiring-org-files (mapcar
			  #'(lambda (f)
                              (expand-file-name (concat f ".org")
                                                "~/common/vehicles/Marmalade"))
			  '("wiring" "switchpanel"))
	org-agenda-files wiring-org-files
	inhibit-startup-screen t)
  (mapcar 'find-file wiring-org-files)
  (switch-to-buffer "wiring.org")
  (display-time)
  (display-battery-mode))

(defun find-connector (row column)
  "Find the description of the connector at ROW COLUMN."
  (interactive "nRow: 
nColumn: ")
  (find-file wiring-connection-file)
  (goto-char (point-min))
  (let ((position (and (search-forward "** To/from hub" (point-max) t)
		       (search-forward (format "Row %d, connector %d" row column)
				       (point-max) t))))
    (if (null position)
	(error "Could not navigate to %d %d" row column)
      (goto-char position)
      (beginning-of-line 3)
      (recenter 2))))

(defun wiring-compact-table ()
  "Make a compact table of some of the wiring."
  (interactive)
  (find-file wiring-connection-file)
  (goto-char (point-min))
  (search-forward "* Connectors for main switch panel")
  (let ((start (point)))
    (org-forward-heading-same-level 1)
    (let ((end (point))
	  (groups nil))
      (goto-char start)
      (while (re-search-forward "^\\s-+| \\([A-Z_]+\\)_\\([1-8]\\) | \\([^|]+?\\)\\s-+|" end t)
	(let ((group (match-string-no-properties 1))
	      (pin (match-string-no-properties 2))
	      (name (match-string-no-properties 3)))
	  (message "group %S pin %S name %S" group pin name)
	  (let ((group-pair (assoc group groups)))
	    (when (null group-pair)
	      (setq group-pair (cons group (make-vector 8 nil))
		    groups (cons group-pair groups)))
	    (aset (cdr group-pair) (1- (string-to-number pin)) name))))
      (find-file "/tmp/ceiling-panel-leads.org")
      (erase-buffer)
      (insert "* Ceiling panel leads\n\n")
      (insert "  | Connector | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |")
      (org-table-hline-and-move)
      (dolist (group-pair (reverse groups))
	(insert (car group-pair) " |")
	(dotimes (pin 8)
	  (insert " " (or (aref (cdr group-pair) pin) " ") " |"))
	(insert "\n" "  | "))
      (beginning-of-line -3)
      (org-table-align)
      (basic-save-buffer))))

(defvar wiring-name-expansions
  '(("Eng" . "Engine")
    ("Fb" . "Fusebox")
    ("Off" . "Offside")
    ("Near" . "Nearside")
    ("O" . "Offside")
    ("N" . "Nearside")
    ("Lp" . "Lamp panel")
    ("Fr" . "Front")
    ("Bulk" . "Bulkhead")
    ("Eng" . "Engine")
    ("Sc" . "Steering column")
    ("Cons" . "Console")
    ("Db" . "Dashboard")
    ("Ceil" . "Ceiling")
    ("Batt" . "Battery")
    ("Bonn" . "Bonnet")
    ("Up" . "Upper")
    ("Nfnm" . "N/S front to N/S mid")
    ("Nmnr" . "N/S mid to N/S rear")))

(defun wiring-expand-short-names (raw)
  "Convert RAW to use longer names."
  (mapconcat (lambda (short)
	       (let ((pair (assoc short wiring-name-expansions)))
		 (if pair
		     (cdr pair)
		   short)))
	     (split-string raw "[ _]")
	     " "))

(defun capitalize-first-word (str)
  "Capitalize the first word of STR."
  (let ((words (split-string str)))
    (if words
        (if (cdr words)
            (concat
             (capitalize (car words))
             " "
             (mapconcat 'identity (cdr words) " "))
          (capitalize (car words)))
      "")))

(defun wiring-to-arduino-program ()
  "Make tables for an arduino program."
  (interactive)
  (find-file wiring-connection-file)
  (goto-char (point-min))
  (let ((strings (make-hash-table :test 'equal))
	(istring 0)
	(connectors (make-hash-table :test 'equal)))
    (let ((unspecified-pins (make-vector 8 nil))))
    (dotimes (i 8)
      (puthash (number-to-string i) i strings))
    (puthash "Unspecified" (vector 0 1 2 3 4 5 6 7) connectors)
    (while (re-search-forward "^ +| \\([A-Z_]+\\)_\\([1-8]\\) +| \\([^|]+?\\) +|" (point-max) t)
      (let ((connector (match-string 1))
	    (pin (string-to-number (match-string 2)))
	    (label (match-string 3)))
	(let ((conn-pins (gethash connector connectors))
	      (string-number (gethash label strings)))
	  (when (null conn-pins)
	    (setq conn-pins (make-vector 8 nil))
	    (aset conn-pins 0 connector)
	    (puthash connector conn-pins connectors))
	  (when (null string-number)
	    (setq string-number istring
		  istring (1+ istring))
	    (puthash label string-number strings))
	  (aset conn-pins (1- pin) string-number))))
    (find-file "/tmp/wiring.ino")
    (erase-buffer)
    (message "Connectors is %S" connectors)
    (insert "#include \"mc8wiring.h\"\n\n")
    (let* ((label-array (make-vector istring nil))
	   (total-bytes 8))
      (maphash #'(lambda (lab ind)
                   (aset label-array ind lab))
	       strings)
      (let ((strings-size (+ (apply '+ (mapcar 'length label-array))
					; add the terminators
			     (length label-array))))
	(insert (format "/* %d characters in %d strings, table occupying %d bytes */\n"
			strings-size
			(length label-array)
			(* 4 (length label-array))
			))
	(setq total-bytes (+ total-bytes strings-size (* 4 (length label-array)))))
      (insert "char *labels[] = {\n"
	      (mapconcat #'(lambda (str) (concat "  \""
                                                 (capitalize-first-word str)
                                                 "\""))
			 label-array
			 ",\n")
	      ",\n  NULL\n};\n\n")
      (let ((names-size 0)
	    (table-size (hash-table-size connectors)))
	(maphash #'(lambda (k v) (setq names-size
                                       (+ names-size 1 (length k))))
		 connectors)
	(let ((table-bytes (* table-size (+ 4 (* 8 2)))))
	  (insert (format "/* %d connectors occupying %d bytes, and %d bytes of connector names */\n"
			  table-size
			  table-bytes
			  names-size))
	  (setq total-bytes (+ total-bytes
			       names-size
			       table-bytes))))
      (let ((i 0)
            (unspecified-index nil))
        (insert "connector connectors[] = {\n")
        (let ((groups nil))
	  (maphash #'(lambda (k v)
                       (push (cons (wiring-expand-short-names
                                    (capitalize k))
                                   (mapconcat #'(lambda (n)
                                                  (if (numberp n)
                                                      (number-to-string n)
                                                    "-1"))
                                              v
                                              ","))
                             groups)
                       )
		   connectors)
	  (dolist (group (sort groups
			       #'(lambda (a b)
                                   (string< (car a) (car b)))))
	    (let ((name (car group))
		  (pins (cdr group)))
              (when (equal name "Unspecified")
                (setq unspecified-index i))
              (setq i (1+ i))
	      (insert "  {\""
		      name
		      "\", {"
		      pins
		      "}},\n"))))
        (insert "  NULL\n};\n")
        (insert (format "int unspecified_index = %d;\n" unspecified-index)))
      (insert (format "/* %d bytes in total */\n" total-bytes)))
    (basic-save-buffer)))

(provide 'wiring)
;;; wiring.el ends here
