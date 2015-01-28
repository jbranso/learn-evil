;; learn-evil--- learn basic evil-mode commands in a game for Emacs

;; Copyright (C) 1997, 2001-2014 Free Software Foundation, Inc.

;; Authors: Kenneth Ozdowy <kozdowy@umich.edu> and Joshua Branso <jbranso@purdue.edu>
;; Version: 0.1
;; Created: 2014-11-22
;; Keywords: games

;; This file is part NOT part of GNU Emacs, but it's so cool that it should be!

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary: This game was inspired by Vim adventures: http://vim-adventures.com/
;;; However, it has the potential to be better. This game can provide an easy way for
;;; an emacs newbie to learn out-of-the-box-commands, vim commands, god-mode commands,
;;; dired commands, or any mode commands.

;;; Code:
(eval-when-compile (require 'cl-lib))

(require 'gamegrid)

;; ;;;;;;;;;;;;; customization variables ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defgroup learn-evil nil
  "Play a game of Learn-Evil."
  :prefix "learn-evil-"
  :group 'games)

(defcustom learn-evil-use-glyphs t
  "Non-nil means use glyphs when available."
  :group 'learn-evil
  :type 'boolean)

(defcustom learn-evil-use-color t
  "Non-nil means use color when available."
  :group 'learn-evil
  :type 'boolean)

(defcustom learn-evil-draw-border-with-glyphs t
  "Non-nil means draw a border even when using glyphs."
  :group 'learn-evil
  :type 'boolean)

(defcustom learn-evil-default-tick-period 0.5
  "The default time taken for a shape to drop one row."
  :group 'learn-evil
  :type 'number)

(defcustom learn-evil-update-speed-function
  'learn-evil-default-update-speed-function
  "Function run whenever the Learn-Evil score changes.
Called with two arguments: (SHAPES ROWS)
SHAPES is the number of shapes which have been dropped.
ROWS is the number of rows which have been completed.

If the return value is a number, it is used as the timer period."
  :group 'learn-evil
  :type 'function)

(defcustom learn-evil-mode-hook nil
  "Hook run upon starting Learn-Evil."
  :group 'learn-evil
  :type 'hook)

(defcustom learn-evil-tty-colors
  ["blue" "red" "red"]
  "Vector of colors of the various shapes in text mode."
  :group 'learn-evil
  :type '(vector (color :tag "Shape 1")
		 (color :tag "Shape 2")
                 (color :tag "Shape 3")))

(defcustom learn-evil-x-colors
					; these are in the format:: [red green blue]
  [[0 0 1]  ;the blue box
   [1 0 0]  ;the red log
   [1 0 0]  ;the other red log
   ]
  "Vector of colors of the various shapes."
  :group 'learn-evil
  :type 'sexp)

(defcustom learn-evil-buffer-name "*Learn-Evil*"
  "Name used for Learn-Evil buffer."
  :group 'learn-evil
  :type 'string)

(defcustom learn-evil-buffer-width 70
  "Width of used portion of buffer."
  :group 'learn-evil
  :type 'number)

(defcustom learn-evil-buffer-height 32
  "Height of used portion of buffer."
  :group 'learn-evil
  :type 'number)

(defcustom learn-evil-width 50
  "Width of playing area."
  :group 'learn-evil
  :type 'number)

(defcustom learn-evil-height 30
  "Height of playing area."
  :group 'learn-evil
  :type 'number)

(defcustom learn-evil-top-left-x 3
  "X position of top left of playing area."
  :group 'learn-evil
  :type 'number)

(defcustom learn-evil-top-left-y 1
  "Y position of top left of playing area."
  :group 'learn-evil
  :type 'number)

(defvar learn-evil-next-x (+ (* 2 learn-evil-top-left-x) learn-evil-width)
  "X position of next shape.")

(defvar learn-evil-next-y learn-evil-top-left-y
  "Y position of next shape.")

(defvar learn-evil-score-x learn-evil-next-x
  "X position of score.")

(defvar learn-evil-score-y (+ learn-evil-next-y 6)
  "Y position of score.")

;; ;;;;;;;;;;;;; display options ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar learn-evil-blank-options
  '(((glyph colorize)
     (t ?\040))
    ((color-x color-x)
     (mono-x grid-x)
     (color-tty color-tty))
    (((glyph color-x) [0 0 0])
     (color-tty "black"))))

(defvar learn-evil-cell-options
  '(((glyph colorize)
     (emacs-tty ?O)
     (t ?\040))
    ((color-x color-x)
     (mono-x mono-x)
     (color-tty color-tty)
     (mono-tty mono-tty))
    ;; color information is taken from learn-evil-x-colors and learn-evil-tty-colors
    ))

(defvar learn-evil-border-options
  '(((glyph colorize)
     (t ?\+))
    ((color-x color-x)
     (mono-x grid-x)
     (color-tty color-tty))
    (((glyph color-x) [0.5 0.5 0.5])
     (color-tty "white"))))

(defvar learn-evil-space-options
  '(((t ?\040))
    nil
    nil))

;; ;;;;;;;;;;;;; constants ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst learn-evil-shapes
  [[[[0  0] [1  0] [0  1] [1  1]]] ; blue square shape 1
   [[[0  0] [1  0] [2  0] [3  0]]]    ;the red log
   [[[1  0] [1  1] [1  2] [1  3]]]]   ;the rotated red log (horizontal)
  "Each shape is described by a vector that contains the coordinates of
each one of its four blocks.")

;;the scoring rules were taken from "xlearn-evil".  Blocks score differently
;;depending on their rotation
(defconst learn-evil-shape-scores
  [[6] ; the blue square ;; the blue square does not need a score anymore; this should be deleted.
   [5] ;the red log
   [5]] ;the rotated log (horizontal)
  )

(defconst learn-evil-shape-dimensions
  [[2 2] ;the square
   [4 1] ;the red log
   [1 4]];the other red log (horizontal)
  )

(defconst learn-evil-blank 7)

(defconst learn-evil-border 8)

(defconst learn-evil-space 9)

(defun learn-evil-default-update-speed-function (_shapes rows)
  (/ 20.0 (+ 50.0 rows)))

;; ;;;;;;;;;;;;; variables ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(cl-defstruct object shape pos-x pos-y)

(defvar learn-evil-n-shapes 0)
(defvar learn-evil-n-rows 0)
(defvar learn-evil-score 0)
(defvar learn-evil-paused nil)
(defvar learn-evil-line-list (list (make-object :shape 1 :pos-x 10 :pos-y 0)))
(defvar learn-evil-player-shape (make-object :shape 0 :pos-x 25 :pos-y 15))
(defvar learn-evil-ticks 0)
(defvar learn-evil-lives 5)

(make-variable-buffer-local 'learn-evil-shape)
(make-variable-buffer-local 'learn-evil-next-shape)
(make-variable-buffer-local 'learn-evil-n-shapes)
(make-variable-buffer-local 'learn-evil-n-rows)
(make-variable-buffer-local 'learn-evil-score)
(make-variable-buffer-local 'learn-evil-paused)
(make-variable-buffer-local 'learn-evil-line-list)
(make-variable-buffer-local 'learn-evil-player-shape)
(make-variable-buffer-local 'learn-evil-ticks)
(make-variable-buffer-local 'learn-evil-lives)

;; ;;;;;;;;;;;;; keymaps ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar learn-evil-mode-map
  (let ((map (make-sparse-keymap 'learn-evil-mode-map)))
    (define-key map "n"		 'learn-evil-start-game)
    (define-key map "q"		 'learn-evil-end-game)
    (define-key map "p"		 'learn-evil-pause-game)

    (define-key map "G"		 'learn-evil-move-bottom)
    (define-key map "L"		 'learn-evil-move-bottom)
    (define-key map (kbd "g g")  'learn-evil-move-top)
    (define-key map  "H"         'learn-evil-move-top)
    (define-key map [left]	 'learn-evil-move-left)
    (define-key map [right]	 'learn-evil-move-right)
    (define-key map "h"          'learn-evil-move-left)
    (define-key map "l"	         'learn-evil-move-right)
    (define-key map (kbd "<up>")          'learn-evil-move-up)
    (define-key map (kbd "<down>")	         'learn-evil-move-down)
    (define-key map "k"          'learn-evil-move-up)
    (define-key map "j"	         'learn-evil-move-down)
    (define-key map "w"          'learn-evil-move-word)
    (define-key map "e"          'learn-evil-move-word-end)
    (define-key map "b"          'learn-evil-move-word-back)
    (define-key map "$"          'learn-evil-move-end-of-line)
    (define-key map "^"          'learn-evil-move-beginning-of-line)
    map))

(defvar learn-god-mode-map
  (let ((map (make-sparse-keymap 'learn-god-mode-map)))

    (define-key map (kbd "p")          'learn-evil-move-up)
    (define-key map (kbd "n")	         'learn-evil-move-down)
    (define-key map (kbd "b")          'learn-evil-move-left)
    (define-key map (kbd "f")	         'learn-evil-move-right)
    (define-key map (kbd "p")          'learn-evil-move-up)
    (define-key map (kbd "n")	         'learn-evil-move-down)
    (define-key map (kbd "b")          'learn-evil-move-left)
    (define-key map (kbd "f")	         'learn-evil-move-right)
    ;;(define-key map "n"		       'learn-evil-start-game)
    map))

(defvar learn-emacs-mode-map
  (let ((map (make-sparse-keymap 'learn-emacs-mode-map)))

    (define-key map (kbd "M-p")          'learn-evil-move-up)
    (define-key map (kbd "M-n")	         'learn-evil-move-down)
    (define-key map (kbd "M-b")          'learn-evil-move-left)
    (define-key map (kbd "M-f")	         'learn-evil-move-right)
    (define-key map (kbd "M-p")          'learn-evil-move-up)
    (define-key map (kbd "M-n")	         'learn-evil-move-down)
    (define-key map (kbd "M-b")          'learn-evil-move-left)
    (define-key map (kbd "M-f")	         'learn-evil-move-right)
    (define-key map "n"		'learn-evil-start-game)
    map))

(defvar learn-evil-null-map
  (let ((map (make-sparse-keymap 'learn-evil-null-map)))
    (define-key map "n"		'learn-evil-start-game)
    map))

;; ;;;;;;;;;;;;;;;; game functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun learn-evil-display-options ()
  (let ((options (make-vector 256 nil)))
    (dotimes (c 256)
      (aset options c
	    (cond ((= c learn-evil-blank)
                   learn-evil-blank-options)
                  ((and (>= c 0) (<= c 2))
		   (append
		    learn-evil-cell-options
		    `((((glyph color-x) ,(aref learn-evil-x-colors c))
		       (color-tty ,(aref learn-evil-tty-colors c))
		       (t nil)))))
                  ((= c learn-evil-border)
                   learn-evil-border-options)
                  ((= c learn-evil-space)
                   learn-evil-space-options)
                  (t
                   '(nil nil nil)))))
    options))

(defun learn-evil-get-tick-period ()
  (if (boundp 'learn-evil-update-speed-function)
      (let ((period (apply learn-evil-update-speed-function
			   learn-evil-n-shapes
			   learn-evil-n-rows nil)))
	(and (numberp period) period))))

(defun learn-evil-get-shape-cell (block obj)
  (aref (aref  (aref learn-evil-shapes
                     (object-shape obj)) 0)
        block))

(defun learn-evil-shape-width (obj)
  (aref (aref learn-evil-shape-dimensions (object-shape obj)) 0))

(defun learn-evil-draw-score ()
  (let ((strings (vector (format "Lives:  %05d" learn-evil-lives)
                         (format "Score:  %05d" learn-evil-score))))
    (dotimes (y 2)
      (let* ((string (aref strings y))
             (len (length string)))
        (dotimes (x len)
          (gamegrid-set-cell (+ learn-evil-score-x x)
                             (+ learn-evil-score-y y)
                             (aref string x)))))))

(defun learn-evil-update-score ()
  (learn-evil-draw-score)
  (let ((period (learn-evil-get-tick-period)))
    (if period (gamegrid-set-timer period))))

(defun learn-evil-new-shape ()
  (setq learn-evil-line-list (append learn-evil-line-list
                                     (list (make-object :shape (+ 1 (random 2)) :pos-x (+ (random 45) 3) :pos-y 0))))
  (learn-evil-draw-shape (car learn-evil-line-list))
  (learn-evil-update-score))

"
(defun learn-evil-draw-next-shape ()
  (dotimes (x 4)
    (dotimes (y 4)
      (gamegrid-set-cell (+ learn-evil-next-x x)
                         (+ learn-evil-next-y y)
                         learn-evil-blank)))
  (dotimes (i 4)
    (let ((learn-evil-shape learn-evil-next-shape)
          (learn-evil-rot 0))
      (gamegrid-set-cell (+ learn-evil-next-x
                            (aref (learn-evil-get-shape-cell i) 0))
                         (+ learn-evil-next-y
                            (aref (learn-evil-get-shape-cell i) 1))
                         (elt learn-evil-shape 0)))))
"

(defun learn-evil-draw-shape (obj)
  (dotimes (i 4)
    (let ((c (learn-evil-get-shape-cell i obj)))
      (gamegrid-set-cell (+ learn-evil-top-left-x
                            (object-pos-x obj)
                            (aref c 0))
                         (+ learn-evil-top-left-y
                            (object-pos-y obj)
                            (aref c 1))
                         (object-shape obj)))))

(defun learn-evil-erase-shape (obj)
  (dotimes (i 4)
    (let ((c (learn-evil-get-shape-cell i obj)))
      (gamegrid-set-cell (+ learn-evil-top-left-x
                            (object-pos-x obj)
                            (aref c 0))
                         (+ learn-evil-top-left-y
                            (object-pos-y obj)
                            (aref c 1))
                         learn-evil-blank))))

(defun learn-evil-test-shape (obj)
  (let ((hit nil))
    (dotimes (i 4)
      (unless hit
        (setq hit
              (let* ((c (learn-evil-get-shape-cell i obj))
                     (xx (+ (object-pos-x obj)
                            (aref c 0)))
                     (yy (+ (object-pos-y obj)
                            (aref c 1))))
                (or (>= xx learn-evil-width)
                    (>= yy learn-evil-height)
                    (/= (gamegrid-get-cell
                         (+ xx learn-evil-top-left-x)
                         (+ yy learn-evil-top-left-y))
                        learn-evil-blank))))))
    hit))

(defun learn-evil-full-row (y)
  (let ((full t))
    (dotimes (x learn-evil-width)
      (if (= (gamegrid-get-cell (+ learn-evil-top-left-x x)
                                (+ learn-evil-top-left-y y))
             learn-evil-blank)
          (setq full nil)))
    full))

(defun learn-evil-draw-border-p ()
  (or (not (eq gamegrid-display-mode 'glyph))
      learn-evil-draw-border-with-glyphs))

(defun learn-evil-init-buffer ()
  (gamegrid-init-buffer learn-evil-buffer-width
			learn-evil-buffer-height
			learn-evil-space)
  (let ((buffer-read-only nil))
    (if (learn-evil-draw-border-p)
	(cl-loop for y from -1 to learn-evil-height do
                 (cl-loop for x from -1 to learn-evil-width do
                          (gamegrid-set-cell (+ learn-evil-top-left-x x)
                                             (+ learn-evil-top-left-y y)
                                             learn-evil-border))))
    (dotimes (y learn-evil-height)
      (dotimes (x learn-evil-width)
        (gamegrid-set-cell (+ learn-evil-top-left-x x)
                           (+ learn-evil-top-left-y y)
                           learn-evil-blank)))
    (if (learn-evil-draw-border-p)
	(cl-loop for y from -1 to 4 do
                 (cl-loop for x from -1 to 4 do
                          (gamegrid-set-cell (+ learn-evil-next-x x)
                                             (+ learn-evil-next-y y)
                                             learn-evil-border))))))

(defun learn-evil-reset-game ()
  (gamegrid-kill-timer)
  (learn-evil-init-buffer)
  (setq learn-evil-n-shapes	0
        learn-evil-n-rows	0
        learn-evil-score	0
        learn-evil-paused	nil
        learn-evil-line-list    nil)
  (learn-evil-new-shape)
  (learn-evil-draw-shape learn-evil-player-shape))

(defun learn-evil-shape-done (obj)
  (learn-evil-erase-shape obj)
  (setq learn-evil-n-shapes (1- learn-evil-n-shapes))
  (setq learn-evil-line-list (cdr learn-evil-line-list))
  (setq learn-evil-score
	(1+ learn-evil-score))
  (learn-evil-update-score))

(defun learn-evil-update-game (learn-evil-buffer)
  "Called on each clock tick.
Drops the shape one square, testing for collision.
Need to call for all in list of lines
"
  ;;every so often make a new shape
  (if (= 7 (mod learn-evil-ticks 8))
      (learn-evil-new-shape))
  ;;error checking
  (if (and (not learn-evil-paused)
	   (eq (current-buffer) learn-evil-buffer))
      (let ((line-list learn-evil-line-list))
        (setq learn-evil-ticks (1+ learn-evil-ticks))
        (let (hit)
          (dolist (shape line-list)
            (learn-evil-erase-shape shape)
            (setf (object-pos-y shape)
                  (1+ (object-pos-y shape)))
            (setf hit (learn-evil-test-shape shape))
            (if hit
                (setf (object-pos-y shape)
                      (1- (object-pos-y shape))))
            (learn-evil-draw-shape shape)
	    ;; if the red or blue object is not object-pos-y < learn-evil-height, then
	    ;; the game should reset and learn-evil-lives =- 1
					;(print (object-pos-y shape))
	    (when (and
		   ;; the red block has not touched the bottom and hit is t.
		   (< (object-pos-y shape) 26)
		   hit)
	      ;;if learn-evil-lives is 1 or more, then -1
	      (if (> learn-evil-lives 0)
		  ;;then
		  (progn
		    (setq  learn-evil-lives (1- learn-evil-lives))
		    (setf (object-pos-x learn-evil-player-shape) 25)
		    (setf (object-pos-y learn-evil-player-shape) 15)
		    (learn-evil-start-game)
		    (return t))
		;;else, end the game
		(learn-evil-end-game)))
	    (if hit
		(learn-evil-shape-done shape)))))))

(defun learn-evil-move-beginning-of-line ()
  "Drop the shape to beginning of the line."
  (interactive)
  (unless learn-evil-paused
    (let ((hit nil))
      (learn-evil-erase-shape learn-evil-player-shape)
      (setf learn-evil-player-orinigal-position (object-pos-x learn-evil-player-shape))
      (setf (object-pos-x learn-evil-player-shape) 0)
      (setq hit (learn-evil-test-shape learn-evil-player-shape))
      (if hit
	  (setf (object-pos-x learn-evil-player-shape) learn-evil-player-orinigal-position)))
    (learn-evil-draw-shape learn-evil-player-shape)))

(defun learn-evil-move-end-of-line ()
  "Drop the shape to the end of the line."
  (interactive)
  (unless learn-evil-paused
    (let ((hit nil))
      (learn-evil-erase-shape learn-evil-player-shape)
      (while (not hit)
        (setf (object-pos-x learn-evil-player-shape) (1+ (object-pos-x learn-evil-player-shape)))
        (setq hit (learn-evil-test-shape learn-evil-player-shape)))
      (setf (object-pos-x learn-evil-player-shape) (1- (object-pos-x learn-evil-player-shape)))
      (learn-evil-draw-shape learn-evil-player-shape))))

(defun learn-evil-move-bottom ()
  "Drop the shape to the bottom of the playing area."
  (interactive)
  (unless learn-evil-paused
    (let ((hit nil))
      (learn-evil-erase-shape learn-evil-player-shape)
      (while (not hit)
        (setf (object-pos-y learn-evil-player-shape) (1+ (object-pos-y learn-evil-player-shape)))
        (setq hit (learn-evil-test-shape learn-evil-player-shape)))
      (setf (object-pos-y learn-evil-player-shape) (1- (object-pos-y learn-evil-player-shape)))
      (learn-evil-draw-shape learn-evil-player-shape))))

(defun learn-evil-move-top ()
  (interactive)
  (unless learn-evil-paused
    (let ((hit nil))
      (learn-evil-erase-shape learn-evil-player-shape)
      (while (not hit)
        (setf (object-pos-y learn-evil-player-shape) (1- (object-pos-y learn-evil-player-shape)))
        (setq hit (learn-evil-test-shape learn-evil-player-shape)))
      (setf (object-pos-y learn-evil-player-shape) (1+ (object-pos-y learn-evil-player-shape))))
    (learn-evil-draw-shape learn-evil-player-shape)))

(defun learn-evil-move-down ()
  "Move the shape one square to the up."
  (interactive)
  (unless learn-evil-paused
    (learn-evil-erase-shape learn-evil-player-shape)
    (setf (object-pos-y learn-evil-player-shape) (1+ (object-pos-y learn-evil-player-shape)))
    (if (learn-evil-test-shape learn-evil-player-shape)
        (setf (object-pos-y learn-evil-player-shape) (1- (object-pos-y learn-evil-player-shape))))
    (learn-evil-draw-shape learn-evil-player-shape)))

(defun learn-evil-move-up ()
  "Move the shape one square to the up."
  (interactive)
  (unless learn-evil-paused
    (learn-evil-erase-shape learn-evil-player-shape)
    (setf (object-pos-y learn-evil-player-shape) (1- (object-pos-y learn-evil-player-shape)))
    (if (learn-evil-test-shape learn-evil-player-shape)
        (setf (object-pos-y learn-evil-player-shape) (1+ (object-pos-y learn-evil-player-shape))))
    (learn-evil-draw-shape learn-evil-player-shape)))

(defun learn-evil-move-left ()
  "Move the shape one square to the left."
  (interactive)
  (unless learn-evil-paused
    (learn-evil-erase-shape learn-evil-player-shape)
    (setf (object-pos-x learn-evil-player-shape) (1- (object-pos-x learn-evil-player-shape)))
    (if (learn-evil-test-shape learn-evil-player-shape)
        (setf (object-pos-x learn-evil-player-shape) (1+ (object-pos-x learn-evil-player-shape))))
    (learn-evil-draw-shape learn-evil-player-shape)))

(defun learn-evil-move-word ()
  "Move the player to the beginning of the next 'word'"
  (interactive)
  (unless learn-evil-paused
    (learn-evil-erase-shape learn-evil-player-shape)
    (let ((i 0))
      (while (and (< i 5) t)
        (setf (object-pos-x learn-evil-player-shape) (1+ (object-pos-x learn-evil-player-shape)))
        (if (learn-evil-test-shape learn-evil-player-shape)
            (setf (object-pos-x learn-evil-player-shape) (1- (object-pos-x learn-evil-player-shape))))
        (setq i (1+ i))))
    (learn-evil-draw-shape learn-evil-player-shape)))

(defun learn-evil-move-word-end ()
  "Move the player to the beginning of the next 'word'"
  (interactive)
  (unless learn-evil-paused
    (learn-evil-erase-shape learn-evil-player-shape)
    (let ((i 0))
      (while (< i 3)
        (setf (object-pos-x learn-evil-player-shape) (1+ (object-pos-x learn-evil-player-shape)))
        (if (learn-evil-test-shape learn-evil-player-shape)
            (setf (object-pos-x learn-evil-player-shape) (1- (object-pos-x learn-evil-player-shape))))
        (setq i (1+ i))))
    (learn-evil-draw-shape learn-evil-player-shape)))

(defun learn-evil-move-word-back ()
  "Move the player to the beginning of the next 'word'"
  (interactive)
  (unless learn-evil-paused
    (learn-evil-erase-shape learn-evil-player-shape)
    (let ((i 0))
      (while (and (< i 5) t)
        (setf (object-pos-x learn-evil-player-shape) (1- (object-pos-x learn-evil-player-shape)))
        (if (learn-evil-test-shape learn-evil-player-shape)
            (setf (object-pos-x learn-evil-player-shape) (1+ (object-pos-x learn-evil-player-shape))))
        (setq i (1+ i))))
    (learn-evil-draw-shape learn-evil-player-shape)))

(defun learn-evil-move-right ()
  "Move the shape one square to the right."
  (interactive)
  (unless learn-evil-paused
    (learn-evil-erase-shape learn-evil-player-shape)
    (setf (object-pos-x learn-evil-player-shape) (1+ (object-pos-x learn-evil-player-shape)))
    (if (learn-evil-test-shape learn-evil-player-shape)
	(setf (object-pos-x learn-evil-player-shape) (1- (object-pos-x learn-evil-player-shape))))
    (learn-evil-draw-shape learn-evil-player-shape)))

(defun learn-evil-end-game ()
  "Terminate the current game."
  (interactive)
  (gamegrid-kill-timer)
  (use-local-map learn-evil-null-map)
  (gamegrid-add-score learn-evil-score-file learn-evil-score))

(defun learn-evil-start-game ()
  "Start a new game of Learn-Evil."
  (interactive)
  (learn-evil-reset-game)
  (use-local-map learn-evil-mode-map)
  (let ((period (or (learn-evil-get-tick-period)
		    learn-evil-default-tick-period)))
    (gamegrid-start-timer period 'learn-evil-update-game)))

(defun learn-evil-pause-game ()
  "Pause (or resume) the current game."
  (interactive)
  (setq learn-evil-paused (not learn-evil-paused))
  (message (and learn-evil-paused "Game paused (press p to resume)")))

(defun learn-evil-active-p ()
  (eq (current-local-map) learn-evil-mode-map))

(put 'learn-evil-mode 'mode-class 'special)

(define-derived-mode learn-evil-mode nil "Learn-Evil"
  "A mode for playing Learn-Evil."

  (add-hook 'kill-buffer-hook 'gamegrid-kill-timer nil t)

  (use-local-map learn-evil-null-map)

  (unless (featurep 'emacs)
    (setq mode-popup-menu
	  '("Learn-Evil Commands"
	    ["Start new game"	learn-evil-start-game]
	    ["End game"		learn-evil-end-game
	     (learn-evil-active-p)]
	    ["Pause"		learn-evil-pause-game
	     (and (learn-evil-active-p) (not learn-evil-paused))]
	    ["Resume"		learn-evil-pause-game
	     (and (learn-evil-active-p) learn-evil-paused)])))

  (setq show-trailing-whitespace nil)

  (setq gamegrid-use-glyphs learn-evil-use-glyphs)
  (setq gamegrid-use-color learn-evil-use-color)

  (gamegrid-init (learn-evil-display-options)))

;;;###autoload
(defun learn-evil ()
  "Play the Learn-Evil game.
Shapes drop from the top of the screen, and the user has to dodge the
falling shapes.

learn-evil-mode keybindings:
   \\<learn-evil-mode-map>
\\[learn-evil-start-game]	Starts a new game of Learn-Evil
\\[learn-evil-end-game]	Terminates the current game
\\[learn-evil-pause-game]	Pauses (or resumes) the current game
\\[learn-evil-move-left]	Moves the shape one square to the left
\\[learn-evil-move-right]	Moves the shape one square to the right
\\[learn-evil-move-bottom]	Drops the shape to the bottom of the playing area
\\[learn-evil-move-top]         Moves the player to the top of the screen
\\[learn-evil-move-beginning-of-line] moves the player to the beginning of the line
\\[learn-evil-move-end-of-line] moves the player to the end of the line
\\[learn-evil-move-word]        Moves the player to the beginning of the next word
\\[learn-evil-move-word-end]    Moves the player to the end of the word
\\[learn-evil-move-word-back]   Moves the player to the beginning of the word

"
  (interactive)

  (select-window (or (get-buffer-window learn-evil-buffer-name)
		     (selected-window)))
  (switch-to-buffer learn-evil-buffer-name)
  (gamegrid-kill-timer)
  (evil-set-initial-state 'learn-evil-mode 'emacs)
  (learn-evil-mode)
  (learn-evil-start-game))

(provide 'learn-evil)

;;; learn-evil.el ends here
