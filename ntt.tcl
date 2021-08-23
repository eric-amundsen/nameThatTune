#!/bin/env tclsh

source snack-win.kit
package require Tk
package require snack

#
# initialize / startup
#
proc initVars {} {
    ######################################################################
    ######################################################################
    ##
    ##
    ## USER SERVICABLE PARTS
    ##
    ##vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

    # debug log filename
    set ::cfg(debugOn)             0
    set ::cfg(logfilename)         "ntt_debug.log.txt"

    # default playlist filename
    set ::cfg(defaultPlaylist)     "my playlist.txt"

    # checkbox var, on next/prev start at begining or random
    # change to 1 to default to random at startup
    set ::cfg(startPosition)       0

    # the number of seconds at the end of a track that random
    # start point isn't allowed to fall in
    set ::cfg(trackEndBuffer)      15

    set ::cfg(bigFont)             {Courier 25}
    set ::cfg(littleFont)          {Courier 15}

    ##^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    ##
    ## USER SERVICABLE PARTS
    ##
    ##
    ######################################################################
    ######################################################################

    set ::trackIndex               -1

    # show hotkeys
    set ::cfg(displayTitleHK)      "t" 
    set ::cfg(displayArtistHK)     "b" 
    set ::cfg(displayAlbumHK)      "a"
    set ::cfg(displayEverythingHK) "e"
    set ::cfg(replayHK)            "r"
    set ::cfg(playBeginningHK)     "s"
    set ::cfg(playPauseHK)         "<space>"
    set ::cfg(next)                "n"
    set ::cfg(prev)                "p"
    set ::cfg(newPlaylist)         "o"
    set ::cfg(quit)                "q"



    # a snack handle to the audio object
    set ::cfg(song)                handle

    logLine "initVars done"

    # clean
    foreach c [winfo children .] {destroy $c}

}

proc logLine {line} {
    if {$::cfg(debugOn)} {
        set fh [open $::cfg(logfilename) a]
        puts -nonewline $fh "\[[clock format [clock seconds] -format "%D %T" -gmt True]\]: "
        puts $fh $line
        close $fh
    }
}

proc readPlaylistFile {filename} {

    logLine "readPlaylistFile open \"$filename\""

    # open/read file
    set fh [open $filename r]
    #fconfigure $fh -encoding unicode
    set tsvLines [split [read $fh] \n]
    close $fh

    logLine "readPlaylistFile successfully opened and read"

    # get top, col heading, line
    set topLine [lindex $tsvLines 0]
    set colNames [split $topLine \t]

    logLine "readPlaylistFile columns : $colNames"

    # get rest
    set tsvLines [lrange $tsvLines 1 end]

    # create a randomized index list
    set tsvLinesLength [llength $tsvLines]

    logLine "readPlaylistFile $tsvLinesLength songs found"

    # by creating an array numbered 0 to number of songs
    for {set j 0} {$j < $tsvLinesLength} {incr j} {
        set idxArr($j) $j
    }

    # loop through the array
    for {set j 0} {$j < $tsvLinesLength} {incr j} {

        # and swap j with a random index
        set randNum [expr {int(rand() * $tsvLinesLength)}]
        set t $idxArr($j)
        set idxArr($j) $idxArr($randNum)
        set idxArr($randNum) $t

    }

    logLine "readPlaylistFile create randomized list"

    # populate the ::tracks array
    # TODO the header line is in unicode, so totally screws with indexing into array
    # so hacked up with column number - BOOO!!!
    set idx 0
    foreach tabbedLine $tsvLines {
        logLine "tabbedLine $tabbedLine"
        set line [split $tabbedLine \t]
        set colNum 0
        for {set j 0} {$j < [llength $colNames]} {incr j} {
            switch $j {
                0  {set col Name}
                1  {set col Artist}
                3  {set col Album}
                30 {set col Location}
                default {set col X}
            }
            if {$col != "X"} {
                set item [lindex $line $j]
                set ::tracks($col,$idxArr($idx)) $item
            }
        }
        incr idx
    }
    logLine "readPlaylistFile created song array"
}

#
# GUI
#
proc buildGui {} {

    logLine "buildGui"
    
    # frame and labels
    set showFrame               [frame .showframe]
    set nameLabel               [label $showFrame.namelabel        -font $::cfg(bigFont) -justify right -relief flat   -text "SONG TITLE :"]
    set artistLabel             [label $showFrame.artistlabel      -font $::cfg(bigFont) -justify right -relief flat   -text "ARTIST/BAND :"]
    set albumLabel              [label $showFrame.albumlabel       -font $::cfg(bigFont) -justify right -relief flat   -text "ALBUM :"]
    set showTitleLabel          [label $showFrame.shownamelabel    -font $::cfg(bigFont)                -relief sunken -textvariable ::track(display,Name)]
    set showArtistLabel         [label $showFrame.showartistlabel  -font $::cfg(bigFont)                -relief sunken -textvariable ::track(display,Artist)]
    set showAlbumLabel          [label $showFrame.showalbumlabel   -font $::cfg(bigFont)                -relief sunken -textvariable ::track(display,Album)]

    set startPointCheckbutton   [checkbutton $showFrame.startpointcheckbutton -text "Start random position" -variable ::cfg(startPosition)]
    set hotkeysLabel            [label $showFrame.hotkeyslabel     -font $::cfg(littleFont) -justify left -text "$::cfg(displayTitleHK) - title\n$::cfg(displayArtistHK) - band\n$::cfg(displayAlbumHK) - album\n$::cfg(displayEverythingHK) - everything\n$::cfg(replayHK) - restart\n$::cfg(playBeginningHK) - beginning\n$::cfg(playPauseHK) - pause/play\n$::cfg(next) - next\n$::cfg(prev) - prev\n$::cfg(newPlaylist) - open playlist file\n$::cfg(quit) - quit"]

    # display
    grid $showFrame             -row 0 -column 0 -sticky new
    grid $nameLabel             -row 0 -column 0 -sticky nes
    grid $artistLabel           -row 1 -column 0 -sticky nes
    grid $albumLabel            -row 2 -column 0 -sticky nes
    grid $showTitleLabel        -row 0 -column 1 -sticky news
    grid $showArtistLabel       -row 1 -column 1 -sticky news
    grid $showAlbumLabel        -row 2 -column 1 -sticky news
    grid $startPointCheckbutton -row 3 -column 0 -columnspan 2 -sticky nws
    grid $hotkeysLabel          -row 4 -column 0 -columnspan 2 -sticky nws

    # and configure
    grid columnconfigure . 0 -weight 1
    grid columnconfigure $showFrame 0 -weight 0
    grid columnconfigure $showFrame 1 -weight 1 -minsize 800

    grid rowconfigure . 0 -weight 0
    grid rowconfigure . 1 -weight 1

    # bind
    foreach case [list toupper tolower] {
        bind . [string $case $::cfg(displayTitleHK)]      "reveal Name"
        bind . [string $case $::cfg(displayArtistHK)]     "reveal Artist"
        bind . [string $case $::cfg(displayAlbumHK)]      "reveal Album"
        bind . [string $case $::cfg(displayEverythingHK)] "reveal Album;reveal Name;reveal Artist"
        bind . [string $case $::cfg(replayHK)]            "playTrackFrom"
        bind . [string $case $::cfg(playBeginningHK)]     "playTrack"
        bind . [string $case $::cfg(next)]                "next"
        bind . [string $case $::cfg(prev)]                "prev"
        bind . [string $case $::cfg(newPlaylist)]         "openPlaylist"
        bind . [string $case $::cfg(quit)]                "quitConfirm"
    }

    # non-letter key bindings
    bind . $::cfg(playPauseHK)         "playPauseToggle"
    bind . <Key-Right>                 "next"
    bind . <Key-Up>                    "next"
    bind . <Key-Left>                  "prev"
    bind . <Key-Down>                  "prev"
    bind . "1"                         "reveal Name"
    bind . "2"                         "reveal Artist"
    bind . "3"                         "reveal Album"
    bind . "4"                         "reveal Album;reveal Name;reveal Artist"

    wm title . "Name That Tune"

    logLine "buildGui gui built"

}

proc resetDisplayTrack {} {
    logLine "resetDisplayTrack"
    set ::track(display,Name)  ""
    set ::track(display,Artist) ""
    set ::track(display,Album)  ""
}

#
# Key binding callback commands
#
proc next {} {
    logLine next
    movingOn 1
}

proc prev {} {
    logLine prev
    movingOn -1
}

proc playTrackFrom {} {
    logLine playTrackFrom
    playTrack $::tracks(startSample,$::trackIndex)
}

proc playTrack {{startSample 0}} {
    logLine "playTrack $startSample"
    $::cfg(song) stop
    logLine "playTrack stopped"
    $::cfg(song) play -start $startSample
    logLine "playTrack started"
}

proc reveal {item} {
    logLine "reveal $item"
    set ::track(display,$item) $::tracks($item,$::trackIndex)
}

proc playPauseToggle {} {

    logLine "playPauseToggle"

    # check current position to see if playing
    set cp1 [$::cfg(song) current_position]

    logLine "playPauseToggle cp1 $cp1"

    # pause if not the same
    if {[set cp2 [$::cfg(song) current_position]] != $cp1} {
        logLine "playPauseToggle changed $cp2"
        $::cfg(song) play
    } else {
        logLine "playPauseToggle no change $cp2"
        $::cfg(song) pause
    }
}

#
# supporting stuff
#

# move to next track, or prev track, depending on direction (1 or -1)
proc movingOn {direction} {

    logLine "movingOn"

    incr ::trackIndex $direction

    logLine "movingOn track $::trackIndex"

    # see if a track exists with this index
    if {[array get ::tracks "Name,$::trackIndex"] == ""} {

        # if not loop back to beginning
        set ::trackIndex 0

        logLine "movingOn tracked rolled over"

    }

    logLine "movingOn openTrack"
    openTrack

    logLine "movingOn checking for startSample"

    # see if this track already has a start time, because we prev'ed / next'ed
    if {[set startSample [lindex [array get ::tracks "startSample,$::trackIndex"] 1]] == ""} {

        logLine "movingOn need startSample"

        set startSample [pickStartSample $::trackIndex]
        set ::tracks(startSample,$::trackIndex) $startSample
    }

    logLine "movingOn startSample $startSample"

    # if long enough
    if {$::tracks(startSample,$::trackIndex) >= 0} {

        logLine "movingOn resetDisplayTrack"
        resetDisplayTrack

        if {$::cfg(startPosition)} {
            logLine "movingOn playTrackFrom"
            playTrackFrom
        } else {
            logLine "movingOn playTrack"
            playTrack
        }

    } else {

        logLine "movingOn skipped : $startSample"

        logLine "movingOn destroy this song"

        catch {::cfg(song) destroy} {}

        # skip this track by calling next again
        movingOn $direction

    }

    logLine "movingOn done"
}

proc openTrack {} {

    logLine "openTrack"

    # destroy old track - catch because might not exist yet
    catch {::cfg(song) destroy} {}

    logLine "openTrack destroyed"

    # open the track
    snack::sound $::cfg(song) -file [file normalize $::tracks(Location,$::trackIndex)]

    logLine "openTrack opened"

}

proc pickStartSample {idx} {

    logLine "pickStartSample"

    # get the length in seconds
    set length [$::cfg(song) length -units seconds]

    logLine "pickStartSample length $length"

    # if it's too short return error code
    if {$length < 2} {

        set startSample -1

    } else {

        if {$length > $::cfg(trackEndBuffer)} {

            # pick a starting point from beginning to ::cfg(trackEndBuffer) seconds less than length
            set startTime [expr {int(($length - $::cfg(trackEndBuffer)) * rand())}]

        } else {

            # otherwise just pick a point
            set startTime [expr {int($length * rand())}]
        }

        logLine "pickStartSample startTime $startTime"

        # convert to relative number of samples
        # since samples is what the play command takes, not seconds
        set startSample [expr {int(($startTime / $length) * [$::cfg(song) length])}]

        logLine "pickStartSample startSample $startSample"
    }

    return $startSample
}

proc openPlaylist {} {
    logLine "openPlaylist"
    if {[set filename [tk_getOpenFile]] != ""} {
        logLine "openPlaylist filename : $filename"
        set ::cfg(defaultPlaylist) $filename
        main
    }
}

proc quitConfirm {} {
    logLine "quitConfirm"
    if {[tk_messageBox -type okcancel -message "Really quit?"] == "ok"} {
        logLine "quitConfirm confirmed"
        exit
    }
}

proc main {} {
    initVars
    logLine "main buildGui"
    buildGui
    logLine "main readPlaylistFile"
    readPlaylistFile $::cfg(defaultPlaylist)
    logLine "main next"
    next
    playPauseToggle
    logLine "main into event loop"
}

main
