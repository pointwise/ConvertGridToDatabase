#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample source code is not supported by Cadence Design Systems, Inc.
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

# load pointwise logo
proc pwLogo {} {
  set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

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

  label $w(Logo) -image [pwLogo] -bd 0 -relief flat

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
