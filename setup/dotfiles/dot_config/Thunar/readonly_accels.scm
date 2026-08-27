; thunar GtkAccelMap rc-file         -*- scheme -*-
;
; Vim keys for Thunar. TASK-189.
;
; Thunar reads this with gtk_accel_map_load() at startup, so only the
; uncommented lines below matter - everything it does not name keeps Thunar's
; own default. Thunar dumps its complete map here on quit, all 125 entries,
; with unset ones commented out; this file is deliberately the short version.
;
; IT IS READ-ONLY ON PURPOSE, and that is the whole reason it survives.
;
; gtk_accel_map_save() runs when Thunar exits and would rewrite this file with
; its own dump, in hash-table order, on every single quit. Tracked and
; writable, that means a chezmoi diff after every session - drift that is pure
; noise, which is how a repository trains you to stop reading drift reports.
; chezmoi's `readonly_` prefix makes it 0444, Thunar's save fails harmlessly,
; and the repository stays the source of truth for the keymap.
;
; The cost is that Thunar's own Shortcuts Editor (Edit -> Configure shortcuts)
; cannot save. Change a binding HERE and run sync.sh; to experiment live,
; `chmod +w ~/.config/Thunar/accels.scm` first and copy what you settle on back
; into this file.
;
; WHAT CANNOT BE DONE HERE, AND WHY
;
; `j` and `k` are missing, and not by choice. A GtkAccelMap binds *menu
; actions*, and moving the selection is not one - the complete action list was
; extracted from the binary and there is no move-cursor, select-next or
; anything like it. Cursor movement belongs to GtkTreeView and GtkIconView,
; which take their keys from GTK's own binding sets, reachable only through
; `-gtk-key-bindings` in gtk.css - and that is global to every GTK application
; on the machine, not scopable to Thunar. So the cursor moves with the arrow
; keys. `gg` and `G` are gone for the same reason, plus a second one: an
; accelerator is one chord, never a sequence, so no two-key vim motion is
; expressible here at all.
;
; That limit is worth weighing in TASK-190 rather than working around. It is
; the honest difference between a keyboard-native file manager and a graphical
; one wearing vim keys.
;
; ONE COLLISION THIS MACHINE CREATES BY ITSELF
;
; Thunar's stock binding for show-hidden is <Primary>h, and on this machine
; that never arrives: keyd's [control] layer rewrites Ctrl+H to Backspace, and
; Thunar binds Backspace to back-alt1. So the stock key silently goes UP a
; directory instead of showing dotfiles. Measured, not guessed - see the
; [control] layer in setup/system/keyd/default.conf. `.` is the replacement,
; and it is a better mnemonic anyway.
;
; The same trap is waiting for Ctrl+J, Ctrl+K and Ctrl+semicolon, which keyd
; also rewrites. Nothing in Thunar binds them today; if something is bound to
; one later it will not work and will not say so.

; Movement: h leaves, l enters. Shift+h and Shift+l are history, like a
; browser's back and forward.
;
; WRITE SHIFT OUT. "H" IS NOT SHIFT+H HERE.
;
; This said "H" and "L" first, and it cost open-parent and open their keys
; without a word. GTK normalises an accelerator's keyval to lower case before
; matching, so "h" and "H" are the SAME accelerator - and gtk_accel_map_load
; changes entries with replace=FALSE, so the second one to load simply does not
; take. Measured, not reasoned about: the Go menu showed Back as `H` and Open
; Parent with no accelerator at all, which is this repository's favourite
; failure shape - a config line that reads as set and does nothing.
;
; Two things follow. Spell Shift as <Shift>. And do not trust the menu's label
; to tell you which you got: gtk_accelerator_get_label() upper-cases every
; letter for display, so a lower-case `y` renders as `Y` in the Edit menu
; whether or not Shift is involved.
(gtk_accel_path "<Actions>/ThunarWindow/open-parent" "h")
(gtk_accel_path "<Actions>/ThunarActionManager/open" "l")
(gtk_accel_path "<Actions>/ThunarStandardView/back" "<Shift>h")
(gtk_accel_path "<Actions>/ThunarStandardView/forward" "<Shift>l")

; Editing. d is cut rather than delete, matching vim, and x is the destructive
; one - which here means the wastebasket, not unlink.
(gtk_accel_path "<Actions>/ThunarActionManager/copy" "y")
(gtk_accel_path "<Actions>/ThunarActionManager/cut" "d")
(gtk_accel_path "<Actions>/ThunarActionManager/paste" "p")
(gtk_accel_path "<Actions>/ThunarActionManager/move-to-trash" "x")
(gtk_accel_path "<Actions>/ThunarActionManager/undo" "u")
(gtk_accel_path "<Actions>/ThunarActionManager/redo" "<Primary>r")
(gtk_accel_path "<Actions>/ThunarStandardView/rename" "r")

; Finding and showing.
(gtk_accel_path "<Actions>/ThunarWindow/search" "slash")
(gtk_accel_path "<Actions>/ThunarWindow/show-hidden" "period")

; Tabs and leaving, both as close to vim as a file manager gets.
(gtk_accel_path "<Actions>/ThunarWindow/new-tab" "t")
(gtk_accel_path "<Actions>/ThunarWindow/close-window" "q")
