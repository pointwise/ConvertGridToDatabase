#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

################################################################################
# This script can be used to turn domains into database surfaces or turn
# connectors into database curves.
################################################################################

package require PWI_Glyph 2.3

pw::Script loadTk

# initialize globals
set databaseSourceEntity "connector"
set splineResult 0

# widget hierarchy
set w(LabelTitle)          .title
set w(FrameMain)           .main
  set w(ConButton)         $w(FrameMain).conbutton
  set w(DomButton)         $w(FrameMain).dombutton
  set w(SplineCheck)       $w(FrameMain).splinecheck
set w(FrameButtons)        .fbuttons
  set w(Logo)              $w(FrameButtons).logo
  set w(OkButton)          $w(FrameButtons).okbutton
  set w(CancelButton)      $w(FrameButtons).cancelbutton


# procedure to let the user select domains with which to work
# returns a list of the selected domains
proc selectDomains {} {

  set domMask [pw::Display createSelectionMask -requireDomain [list]]
  pw::Display selectEntities \
      -description "Select the domains you would like to convert." \
      -selectionmask $domMask selection
  return $selection(Domains)
}

# procedure to let the user select connectors with which to work
# returns a list of such connectors
proc selectConnectors { } {

  set conMask [pw::Display createSelectionMask -requireConnector [list] \
      -blockConnector "Pole"]
  pw::Display selectEntities \
      -description "Select the connectors you would like to convert." \
      -selectionmask $conMask selection
  set cons $selection(Connectors)
}

# procedure to get the structured domains from the list (returns as list)
proc getStructuredDomains { domains } {
  set structured [list]
  foreach dom $domains {
    if {[$dom getType] eq "pw::DomainStructured"} {
      lappend structured $dom
    }
  }
  return $structured
}

# procedure to get the unstructured domains from the list (returns as list)
proc getUnstructuredDomains { domains } {
  set unstructured [list]
  foreach dom $domains {
    if {[$dom getType] eq "pw::DomainUnstructured"} {
      lappend unstructured $dom
    }
  }
  return $unstructured
}

# convert structured domains
proc convertStructuredDomains { doms } {
  if { [llength $doms] == 0 } {
    return [list]
  }

  set structuredFile [file join [file dirname [info script]] \
                                "convertToDatabaseTempStructured.x"]

    set entities [list]
    foreach dom $doms {
    # save structured domains to file
      set mode [pw::Application begin GridExport $dom]
        $mode initialize -type PLOT3D $structuredFile
          if {![$mode verify]} {
            $mode abort
            return -code error "Verification failed"
          }
        $mode write
      $mode end

      set entity [pw::Database import -type PLOT3D $structuredFile]
      set name "converted_"
      append name [$dom getName]
      $entity setName $name
      lappend entities $entity
    }

  # delete structured domain file
  file delete $structuredFile

  return $entities
}

# convert unstructured domains
proc convertUnstructuredDomains { doms } {
  if { [llength $doms] == 0 } {
    return [list]
  }

  set unstructuredFile [file join [file dirname [info script]] \
                                  "convertToDatabaseTempUnstructured.stl"]

    set entities [list]
    # loop through domains; for unstructured with STL
    # (if done all at once will come back as one domain)
    foreach dom $doms {

      # save unstructured domains to file
      set mode [pw::Application begin GridExport $dom]
        $mode initialize -type STL $unstructuredFile
        if {![$mode verify]} {
          $mode abort
          return -code error "Verification failed"
        }
        $mode write
      $mode end

      set entity [pw::Database import -type STL $unstructuredFile]
      set name "converted_"
      append name [$dom getName]
      $entity setName $name
      lappend entities $entity
    }

  # delete unstructured domain file
  file delete $unstructuredFile

  return $entities
}

proc convertCons { cons } {
  set dbs [list]
  foreach con $cons {
    set db [pw::Curve create]
    set name "converted_"
    append name [$con getName]
    $db setName $name
    set nsegs [$con getSegmentCount]
    for { set iseg 1 } { $iseg <= $nsegs } { incr iseg } {
      set conseg [$con getSegment $iseg]
      set dbseg [[$conseg getType] create]
      switch [$conseg getType] {
        pw::SegmentCircle {
          $dbseg addPoint [$conseg getPoint 1]
          $dbseg addPoint [$conseg getPoint 2]
          switch [$conseg getAlternatePointType] {
            Shoulder {
              $dbseg setShoulderPoint [$conseg getShoulderPoint] \
                  [$conseg getNormal]
            }
            Center {
              $dbseg setCenterPoint [$conseg getCenterPoint] [$conseg getNormal]
            }
            Angle {
              $dbseg setAngle [$conseg getAngle] [$conseg getNormal]
            }
            EndAngle {
              $dbseg setEndAngle [$conseg getAngle] [$conseg getNormal]
            }
            default {
            }
          }
        }
        pw::SegmentConic {
          $dbseg addPoint [$conseg getPoint 1]
          $dbseg addPoint [$conseg getPoint 2]
          switch [$conseg getAlternatePointType] {
            Shoulder {
              $dbseg setShoulderPoint [$conseg getShoulderPoint]
            }
            Intersect {
              $dbseg setIntersectPoint [$conseg getIntersectPoint]
            }
            default {
            }
          }
          $dbseg setRho [$conseg getRho]
        }
        pw::SegmentSpline {
          set npts [$conseg getPointCount]
          for { set ipt 1 } { $ipt <= $npts } { incr ipt } {
            $dbseg addPoint [$conseg getPoint $ipt]
          }
          $dbseg setSlope [$conseg getSlope]
          if { [$conseg getSlope] eq "Free" } {
            for { set ipt 2 } { $ipt <= $npts } { incr ipt } {
              $dbseg setSlopeIn $ipt [$conseg getSlopeIn $ipt]
            }
            for { set ipt 1 } { $ipt < $npts } { incr ipt } {
              $dbseg setSlopeOut $ipt [$conseg getSlopeOut $ipt]
            }
          }
        }
        pw::SegmentSurfaceSpline {
          set npts [$conseg getPointCount]
          for { set ipt 1 } { $ipt <= $npts } { incr ipt } {
            $dbseg addPoint [$conseg getPoint $ipt]
          }
          $dbseg setSlope [$conseg getSlope]
          if { [$conseg getSlope] eq "Free" } {
            for { set ipt 2 } { $ipt <= $npts } { incr ipt } {
              $dbseg setSlopeIn $ipt [$conseg getSlopeIn $ipt]
            }
            for { set ipt 1 } { $ipt < $npts } { incr ipt } {
              $dbseg setSlopeOut $ipt [$conseg getSlopeOut $ipt]
            }
          }
        }
        default {
        }
      }
      $db addSegment $dbseg
    }
    lappend dbs $db
  }
}

# respond to ok being pressed
proc okAction { } {

  if {$::databaseSourceEntity eq "connector"} {
    set cons [selectConnectors ]
    convertCons $cons
  } else {
    set doms [selectDomains ]

    if {[catch {
      set structured [getStructuredDomains $doms]
      set entities [convertStructuredDomains $structured]

      set unstructured [getUnstructuredDomains $doms]
      lappend entities [convertUnstructuredDomains $unstructured]
    
      if {$::splineResult} {
        foreach entity $entities {
          if { ! ($entity eq "") } {
            if { [$entity getType] eq "pw::Curve" \
                  || [$entity getType] eq "pw::Surface" } {
              $entity spline
            }
          }
        }
      }
    }]} { ;# catch section below
      puts "Verification failed. Some of your entities could not be converted."
    }
  }
}

# set the font for the input widget to be bold and 1.5 times larger than
# the default font
proc setTitleFont { l } {
  global titleFont
  if { ! [info exists titleFont] } {
    set fontSize [font actual TkCaptionFont -size]
    set titleFont [font create -family [font actual TkCaptionFont -family] \
        -weight bold -size [expr {int(1.5 * $fontSize)}]]
  }
  $l configure -font $titleFont
}

# load a GIF image from a file in base-64 encoded form
# proc loadImage { fname } {
#   set fd [open [file join [file dirname [info script]] $fname] r]
#   set data [read -nonewline $fd]
#   return [image create photo -format GIF -data $data]
# }

# load Cadence Design Systems logo
proc cadenceLogo {} {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

  return [image create photo -format GIF -data $logoData]
}


# build the user interface
proc makeWindow { } {
  global w opt

  # create the widgets
  label $w(LabelTitle) -text "Convert Entities From Grid To Database"
  setTitleFont $w(LabelTitle)

  frame $w(FrameMain)

  radiobutton $w(ConButton) -text "Convert connectors" \
      -variable databaseSourceEntity -value connector -anchor w \
      -command { $w(SplineCheck) configure -state disabled }
  radiobutton $w(DomButton) -text "Convert domains" \
      -variable databaseSourceEntity -value domain -anchor w \
      -command { $w(SplineCheck) configure -state normal }
  checkbutton $w(SplineCheck) -text "Spline resulting surfaces" \
      -variable splineResult -anchor w -padx 20 -state disabled

  frame $w(FrameButtons) -relief sunken

  label $w(Logo) -image [cadenceLogo] -bd 0 -relief flat

  button $w(OkButton) -text "OK" -width 12 -bd 2 \
      -command { wm withdraw . ; okAction ; exit }
  button $w(CancelButton) -text "Cancel" -width 12 -bd 2 \
      -command { exit }

  # lay out the form
  pack $w(LabelTitle) -side top
  pack [frame .sp -bd 1 -height 2 -relief sunken] -pady 4 -side top -fill x
  pack $w(FrameMain) -side top -fill both -expand 1

  # lay out the form in a grid
  grid $w(ConButton) -sticky ew -pady 3 -padx 3
  grid $w(DomButton) -sticky ew -pady 3 -padx 3
  grid $w(SplineCheck) -sticky ew -pady 3 -padx 3

  # lay out buttons
  pack $w(CancelButton) $w(OkButton) -pady 3 -padx 3 -side right
  pack $w(Logo) -side left -padx 5

  # give extra space to (only) column
  grid columnconfigure $w(FrameMain) 1 -weight 1

  pack $w(FrameButtons) -fill x -side bottom -padx 2 -pady 4 -anchor s

  focus $w(ConButton)
  raise .

  # don't allow window to resize
  wm resizable . 0 0
}

makeWindow

tkwait window .

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
