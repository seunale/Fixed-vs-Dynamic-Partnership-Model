globals[
  day
  week
  year
  shared-injections
  annual-total-chronic
  treatment-chance
  transmission-data  ;; List to store transmission events (who infected whom)
  current-run-id
  run-counter
  transmission-steps  ;; Store each step where transmission occurred
  annual-new-infections      ;; List of number of new infections per year
  annual-incidence-rate      ;; List of incidence rates per year
  annual-prevalence-rate     ;; List of annual HCV prevalence rates
  annual-total-cured
  annual-on-treatment
  annual-ever-treated
  prob-syringe-sharing-outer
  prob-syringe-sharing-inner
  prob-syringe-sharing-core
  infection-rate
  ]








breed [pwids pwid]





pwids-own [
  susceptible?
  chronic?
  on-going-treatment?
  cured?
  resistant?
  injection-partners ; list of pwids they share injections with
  syringe-sharer?   ; true if the pwid shares syringes
  injections-per-month  ; number of injections per month
  CC_it              ; critical contacts at time t
  R_it               ; risk factor at time t
  injection-per-day
  was-infected-this-year?
  tmp-total-partner-inj
  tmp-infectious-partner-inj
  infectious-sampled-partners
  treatment-days
  daily-proximity-partners
  ever-started-treatment?
  treatment-rate
  clearing-rate
  treatment-peer-effect
  contact-radius
]







to setup
  ;; increment run id  persist across runs
  set run-counter run-counter + 1
  set current-run-id run-counter

  ;; clear world WITHOUT resetting globals like run-counter since the R0 is estimated across many runs
  clear-turtles
  clear-links
  clear-patches
  reset-ticks

  setup-pwids
  setup-injection-behavior
  setup-groups
  set-sharing-rates
  setup-network
  set annual-total-chronic []
  set transmission-data []
  set transmission-steps []
  set annual-new-infections []
  set annual-incidence-rate []
  set annual-prevalence-rate []
  set annual-total-cured []
  set annual-on-treatment []
  set annual-ever-treated []
  set day 1
  set week 1
  set year 1
end













to-report daily-sampled-injections
  let d random-poisson (injections-per-month / 28)
  if d > 5 [ set d 5 ]
  report round d
end









to setup-pwids
  set-default-shape pwids "person"
  ;; choose population size by switch
  let pop-size ifelse-value full-population?
  [ full-population-size ]
  [ sharers-only-size ]
  create-pwids pop-size [ ; total population size
    setxy random-xcor random-ycor
    set susceptible? true
    set color blue
    set chronic? false
    set on-going-treatment? false
    set cured? false
    set resistant? false
    set syringe-sharer? false
    set was-infected-this-year? false
    set ever-started-treatment? false
    set treatment-rate 0.13
    set clearing-rate 0.3
    set infection-rate 0.76
    set treatment-peer-effect 0.2
    set contact-radius 1
    set injections-per-month random 84  ;
    set tmp-total-partner-inj 0
    set tmp-infectious-partner-inj 0
    set infectious-sampled-partners []
    set CC_it 0  ; Initialize critical contacts
    set R_it 0   ; Initialize risk factor
    set injection-per-day daily-sampled-injections  ;; <== Assign value from reporter
    set treatment-days 0
    set label ""

  ]

  ; Infect  initial agents with HCV
  ask n-of initial-infected pwids [
    set chronic? true
    set color red
    set susceptible? false]
end














to setup-injection-behavior
  ; Randomly assign s as syringe sharers
  ask n-of sharers-only-size pwids [
    set syringe-sharer? true
    ;if debug-mode? [
     ; print (word "PWID " count pwids with [syringe-sharer?] " syringe-sharer?")
    ;]
  ]
end









to setup-groups
  ;; Only select from syringe sharers
  let eligible-sharers pwids with [syringe-sharer?]

  ;; assign CORE first
  let actual-num-core min (list num-core count eligible-sharers)
  if actual-num-core > 0 [
    ask n-of actual-num-core eligible-sharers [
      set label "core"
      set color orange
    ]
  ]

  ;; assign INNER from remaining sharers
  set eligible-sharers pwids with [syringe-sharer? and label = ""]
  let actual-num-inner min (list num-inner count eligible-sharers)
  if actual-num-inner > 0 [
    ask n-of actual-num-inner eligible-sharers [
      set label "inner"
      set color yellow
    ]
  ]

  ;; assign OUTER from remaining sharers
  set eligible-sharers pwids with [syringe-sharer? and label = ""]
  let actual-num-outer min (list num-outer count eligible-sharers)
  if actual-num-outer > 0 [
    ask n-of actual-num-outer eligible-sharers [
      set label "outer"
      set color cyan
    ]
  ]

  ;; safeguard: any remaining sharers -> OUTER
  ask pwids with [syringe-sharer? and label = ""] [
    set label "outer"
    set color cyan
  ]
end










to setup-network
  let core-links 0
  let inner-links 0
  let outer-links 0

  let sharers pwids with [syringe-sharer?]
  let eligible-all sharers with [label = "core" or label = "inner" or label = "outer"]
  let eligible-core sharers with [label = "core"]
  let eligible-inner sharers with [label = "inner"]
  let eligible-outer sharers with [label = "outer"]

  ;; CORE links: ego from core, partner from everyone
  if count eligible-core > 0 and count eligible-all > 1 [
    while [core-links < core-link] [
      ask one-of eligible-core [
        let partner one-of other eligible-all with [not link-neighbor? myself]
        if partner != nobody [
          create-link-with partner [ set color gray set thickness 0.5 ]
          set core-links core-links + 1
        ]
      ]
    ]
  ]

  ;; INNER links: ego from inner, partner from everyone
  if count eligible-all > 1 [
    while [inner-links < inner-link] [
      ask one-of eligible-all [
        let partner one-of other eligible-all with [not link-neighbor? myself]
        if partner != nobody [
          create-link-with partner [ set color gray set thickness 0.5 ]
          set inner-links inner-links + 1
        ]
      ]
    ]
  ]

  ;; OUTER links: ego from outer, partner from everyone
  if count eligible-outer > 0 and count eligible-all > 1 [
    while [outer-links < outer-link] [
      ask one-of eligible-outer [
        let partner one-of other eligible-all with [not link-neighbor? myself]
        if partner != nobody [
          create-link-with partner [ set color gray set thickness 0.5 ]
          set outer-links outer-links + 1
        ]
      ]
    ]
  ]

  ;;if debug-mode? [
   ;; print (word "Core Links: " core-links)
   ;; print (word "Inner Links: " inner-links)
    ;;print (word "Outer Links: " outer-links)
    ;;print (word "Total links: " count links)
  ;;]
end
















to go
  if year = 7 [
    export-transmission-data
    stop
  ]

  ;; Reset daily accumulators + move + sample injections
  ask pwids [
    set tmp-total-partner-inj 0
    set tmp-infectious-partner-inj 0
    set infectious-sampled-partners []
    set daily-proximity-partners []

    set injection-per-day daily-sampled-injections
    move
  ]

  ;; Build today's proximity contacts
  if proximity-risk? [
    do-proximity-interactions
  ]

  ;;  Treatment uses TODAY’s peers
  ask pwids [
    start-treatment
  ]

  ;;  Infection dynamics
  ask pwids [
    if susceptible? [
      calculate-risk-factor
      calculate-critical-contacts
      check-infection-status
    ]
  ]

  clock
  tick
end
















to move

  right random 180
  forward 1
end






to do-proximity-interactions
  let core-sharers  pwids with [syringe-sharer? and label = "core"]
  let inner-sharers pwids with [syringe-sharer? and label = "inner"]
  let outer-sharers pwids with [syringe-sharer? and label = "outer"]

  let core-interactions  min list core-interactions-per-day total-interactions-per-day
  let remaining-after-core (total-interactions-per-day - core-interactions)

  let inner-interactions min list inner-interactions-per-day remaining-after-core
  let outer-interactions (total-interactions-per-day - core-interactions - inner-interactions)

  ;; Fallbacks (if a group is empty, push its budget to OUTER by default)
  if not any? core-sharers [
    set outer-interactions outer-interactions + core-interactions
    set core-interactions 0
  ]
  if not any? inner-sharers [
    set outer-interactions outer-interactions + inner-interactions
    set inner-interactions 0
  ]
  if not any? outer-sharers [
    ;; if outer is empty, push remainder to INNER, then CORE
    if any? inner-sharers [
      set inner-interactions inner-interactions + outer-interactions
      set outer-interactions 0
    ]
    if (outer-interactions > 0) and any? core-sharers [
      set core-interactions core-interactions + outer-interactions
      set outer-interactions 0
    ]
  ]

  ;; CORE interactions
  repeat core-interactions [
    let ego one-of core-sharers
    if ego != nobody [ ask ego [ proximity-step ] ]
  ]

  ;; INNER interactions
  repeat inner-interactions [
    let ego one-of inner-sharers
    if ego != nobody [ ask ego [ proximity-step ] ]
  ]

  ;; OUTER interactions
  repeat outer-interactions [
    let ego one-of outer-sharers
    if ego != nobody [ ask ego [ proximity-step ] ]
  ]
end











to proximity-step
  let candidates other pwids in-radius contact-radius
    with [syringe-sharer? and (label = "core" or label = "inner" or label = "outer")]

  if any? candidates [
    let partner one-of candidates

    if not member? partner daily-proximity-partners [
      set daily-proximity-partners lput partner daily-proximity-partners
    ]

    set tmp-total-partner-inj tmp-total-partner-inj + [injection-per-day] of partner

    if [chronic? or resistant?] of partner [
      set tmp-infectious-partner-inj tmp-infectious-partner-inj + [injection-per-day] of partner
      if not member? partner infectious-sampled-partners [
        set infectious-sampled-partners lput partner infectious-sampled-partners
      ]
    ]
  ]
end




to set-sharing-rates

  if sharing-rate-sensitivity-level = "low" [
    set prob-syringe-sharing-outer 0.027
    set prob-syringe-sharing-inner 0.0825
    set prob-syringe-sharing-core 0.2475
  ]

  if sharing-rate-sensitivity-level = "baseline" [
    set prob-syringe-sharing-outer 0.036
    set prob-syringe-sharing-inner 0.110
    set prob-syringe-sharing-core 0.330
  ]

  if sharing-rate-sensitivity-level = "high" [
    set prob-syringe-sharing-outer 0.045
    set prob-syringe-sharing-inner 0.1375
    set prob-syringe-sharing-core 0.4125
  ]

end










to calculate-risk-factor
  if not syringe-sharer? [
    set R_it 0
    stop
  ]

  ;; ---- Choose peer set for averaging  ----
  let peers nobody
  if proximity-risk? [
    if not empty? daily-proximity-partners [
      set peers turtle-set daily-proximity-partners
    ]
  ]
  if not proximity-risk? [
    if any? link-neighbors [
      set peers link-neighbors
    ]
  ]

  ;; ---- Gather peer group-specific sharing rates for avg switch ----
  let neighbor-probs []

  if peers != nobody and any? peers [
    ask peers [
      if label = "core"  [ set neighbor-probs lput prob-syringe-sharing-core  neighbor-probs ]
      if label = "inner" [ set neighbor-probs lput prob-syringe-sharing-inner neighbor-probs ]
      if label = "outer" [ set neighbor-probs lput prob-syringe-sharing-outer neighbor-probs ]
    ]
  ]

  ;; include ego’s own group probability in the average
  if label = "core"  [ set neighbor-probs lput prob-syringe-sharing-core  neighbor-probs ]
  if label = "inner" [ set neighbor-probs lput prob-syringe-sharing-inner neighbor-probs ]
  if label = "outer" [ set neighbor-probs lput prob-syringe-sharing-outer neighbor-probs ]

  let avg-prob 0
  if length neighbor-probs > 0 [ set avg-prob mean neighbor-probs ]

  ;; ---- Daily on/off: if no sharing “today”, risk is zero ----
  ;if random-float 1 > avg-prob [
    ;set R_it 0
    ;stop
  ;]

  ;; ---- If sharing today, use EGO group probability for SH_i ----
  let pshare 0
  if label = "core"  [ set pshare prob-syringe-sharing-core  ]
  if label = "inner" [ set pshare prob-syringe-sharing-inner ]
  if label = "outer" [ set pshare prob-syringe-sharing-outer ]

  ;; ---- Proximity mode: use today's accumulated proximity injections ----
  if proximity-risk? [
    if tmp-total-partner-inj <= 0 [ set R_it 0 stop ]
    set R_it pshare * (tmp-infectious-partner-inj / tmp-total-partner-inj)
    stop
  ]

  ;; ---- Network mode: use link-neighbors injections ----
  let total-partner-injections sum [injection-per-day] of link-neighbors
  let weighted-infectious-partners sum [
    (ifelse-value (chronic? or resistant?) [1] [0]) * injection-per-day
  ] of link-neighbors

  set shared-injections (injection-per-day * pshare)

  if (injection-per-day > 0 and total-partner-injections > 0) [
    let SH_i shared-injections / injection-per-day
    set R_it SH_i * (weighted-infectious-partners / total-partner-injections)
  ]
  if not (injection-per-day > 0 and total-partner-injections > 0) [
    set R_it 0
  ]
end













to calculate-critical-contacts
  set CC_it (injection-per-day * R_it)    ;; CC_it per day
  ;if debug-mode? [
   ; print (word "PWID " who " CC_it.="CC_it)
 ; ]
end








to check-infection-status
  ;; Daily application
  if not syringe-sharer? [ stop ]

  ;; P(infect) = 1 - (1 - T) ^ CC_it
  let infection-prob 1 - ((1 - infection-rate / 364) ^ CC_it)
  ;if debug-mode? [
  ;  print (word "PWID " who " infection-prob.=" infection-prob)
  ;]

  ;; Single Bernoulli draw
  if random-float 1 < infection-prob [
        set was-infected-this-year? true

    ;; Record infector -> infected (needed for R0)
    if proximity-risk? [
      ;; infectious-sampled-partners is a LIST of turtles
      if not empty? infectious-sampled-partners [
        let chosen-infector one-of infectious-sampled-partners
        record-transmission [who] of chosen-infector who
      ]
    ]

    if not proximity-risk? [
      ;; link-neighbors with
      let infectors link-neighbors with [chronic? or resistant?]
      if any? infectors [
        let chosen-infector one-of infectors
        record-transmission [who] of chosen-infector who
      ]
    ]

    ;; Update infection state (ONLY when infection occurs)
    set chronic? true
    set susceptible? false
    set color red

    ;; HCV clearance
    let average-duration random-normal (7 * 4 * 6) 7
    if random-float 1 < (clearing-rate / average-duration) [
      set chronic? false
      set susceptible? true
      set color blue
    ]
  ]
end





















to start-treatment
  if (chronic? or resistant?) and (not on-going-treatment?) [

    let days-per-year 364
    let base-chance 1 - ((1 - treatment-rate) ^ (1 / days-per-year))

    ;; choose peer set depending on mode
    let peers nobody
    if proximity-risk? [
      if not empty? daily-proximity-partners [
        set peers turtle-set daily-proximity-partners
      ]
    ]
    if not proximity-risk? [
      if any? link-neighbors [
        set peers link-neighbors
      ]
    ]

    let peer-frac 0
    if peers != nobody and any? peers [
      set peer-frac mean [ ifelse-value on-going-treatment? [1] [0] ] of peers
    ]

    ;; multiplicative diffusion
    let p-start min list 1 (base-chance * (1 + treatment-peer-effect * peer-frac))

    if random-float 1 < p-start [
      set on-going-treatment? true
      set ever-started-treatment? true
      set color yellow
      ;;  if on-treatment should still count as infected:
      set chronic? true


      set treatment-days 0
    ]
  ]

  if on-going-treatment? [
    cure-or-resist
  ]
end
























to cure-or-resist
  if on-going-treatment? [
    set treatment-days treatment-days + 1

    ;; end of treatment course (12 weeks = 84 days)
    if treatment-days >= 84 [
      set on-going-treatment? false

      ifelse random-float 1 < 0.9 [
        ;; cured
        set cured? true
        set chronic? false
        set resistant? false
        set color green
        if debug-mode? [
      print (word "PWID " who " is cured")
      ]
      ] [
        ;; not cured => resistant
        set resistant? true
        set cured? false
        set chronic? false
        set color grey
      ]
    ]
  ]

  if cured? [
    ;; loss of treatment-induced immunity
    let loss-of-treatment-induced-immunity 0.07 / 364
    if random-float 1 < loss-of-treatment-induced-immunity [
      reset-as-susceptible
    ]
  ]
end











to reset-as-susceptible
  setxy random-xcor random-ycor
  set susceptible? true
  set color blue
  set chronic? false
  set on-going-treatment? false
  set cured? false
  set resistant? false
  set injections-per-month random 84 ;
end









to clock
  ;; Increment day
  set day day + 1

  ;; 7 days per week
  if day > 7 [
    set day 1
    set week week + 1
  ]

  ;; 52 weeks per year (364 days)
  if week > 52 [
    record-annual-data
    set week 1
    set day 1
    set year year + 1
  ]
end





















to record-annual-data
  let current-year year

  ;; Total chronic cases
  let total-chronic-pwids count pwids with [chronic?]
  set annual-total-chronic lput total-chronic-pwids annual-total-chronic
  if debug-mode? [
    print (word "Annual Chronic PWIDs: " total-chronic-pwids)
  ]

  ;;Total cured agents
  let total-cured-pwids count pwids with [cured?]
  set annual-total-cured lput total-cured-pwids annual-total-cured
  if debug-mode? [
    print (word "Annual Cured PWIDs: " total-cured-pwids)
  ]

  ;; Cummulative on treatment
  let total-ever-treated count pwids with [ever-started-treatment?]
  set annual-ever-treated lput total-ever-treated annual-ever-treated


 ;;Total on treatment agents
  let total-on-treatment-pwids count pwids with [on-going-treatment?]
  set annual-on-treatment lput total-on-treatment-pwids annual-on-treatment
  if debug-mode? [
    print (word "Annual on treament PWIDs: " total-on-treatment-pwids)
  ]


  ;; New infections this year
  let new-infections count pwids with [was-infected-this-year?]
  set annual-new-infections lput new-infections annual-new-infections
  if debug-mode? [
    print (word "New infections this year: " new-infections)
  ]

  ;; Incidence rate
  let total-susceptible count pwids with [susceptible? or was-infected-this-year?]
  let incidence-rate ifelse-value (total-susceptible > 0)
                      [ new-infections / total-susceptible ]
  [ 0 ]
  set annual-incidence-rate lput incidence-rate annual-incidence-rate
 ; if debug-mode? [
    ;print (word "Incidence rate this year: " incidence-rate)
  ;]

  ;; Prevalence rate = chronic / total
  let prevalence-rate total-chronic-pwids / count pwids
  set annual-prevalence-rate lput prevalence-rate annual-prevalence-rate
  ;if debug-mode? [
   ; print (word "Prevalence rate this year: " prevalence-rate)
;  ]

  ;; Reset flags for next year
  ask pwids [ set was-infected-this-year? false ]
end







to record-transmission [infector-id infected-id]
  ;; rule: cannot infect self
  if infector-id = infected-id [ stop ]

  let current-step ticks

  ;; unique key per run + directed pair (infector -> infected)
  let pair-key (list current-run-id infector-id infected-id)

  if debug-mode? [
    print (word "Attempting to record transmission: " pair-key)
  ]

  ;; rule: don't record same infector->infected more than once (per run)
  if not member? pair-key transmission-data [
    set transmission-data lput pair-key transmission-data
    set transmission-steps lput current-step transmission-steps

    if debug-mode? [
      print (word "Recorded transmission event at step " current-step ": " pair-key)
    ]
  ]
end








to export-transmission-data
  let filename "transmission_data.csv"

  carefully [
    ;; Write header only once (when file doesn't exist yet)
    if not file-exists? filename [
      file-open filename
      file-print "run_id,infector,infected,step"
      file-close
    ]

    ;; Append this run's records
    file-open filename

    let step-index 0
    foreach transmission-data [
      record ->
      let run-id item 0 record
      let infector-id item 1 record
      let infected-id item 2 record
      let step item step-index transmission-steps
      file-print (word run-id "," infector-id "," infected-id "," step)
      set step-index step-index + 1
    ]

    file-close
    print (word "Transmission data appended successfully for run " current-run-id ".")
  ]
  [
    file-close-all
    print (word "Error occurred while exporting transmission data: " error-message)
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
826
19
1237
431
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-15
15
-15
15
0
0
1
ticks
30.0

SLIDER
15
188
196
221
initial-infected
initial-infected
1
20000
985.0
1
1
pwids
HORIZONTAL

BUTTON
9
222
72
255
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
75
222
138
255
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
140
223
203
256
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1406
57
1909
407
Pwid Proportions
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"chronic?" 1.0 0 -2674135 true "" "plot count pwids with [ chronic? ]/ (count pwids) * 100"
"cured?" 1.0 0 -7500403 true "" "plot count pwids with [ cured? ]/ (count pwids) * 100"
"on-going-treatment?" 1.0 0 -1184463 true "" "plot count pwids with [ on-going-treatment? ]/ (count pwids) * 100"

MONITOR
392
319
449
364
NIL
week
17
1
11

MONITOR
451
319
508
364
NIL
year
17
1
11

TEXTBOX
372
298
463
316
output monitors
12
0.0
1

TEXTBOX
1570
37
1720
56
plots
15
0.0
1

PLOT
1407
408
1879
794
Basic Reproduction Number
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot R0"

MONITOR
332
320
389
365
NIL
day
17
1
11

SLIDER
613
328
785
361
num-links
num-links
0
10000
1802.0
1
1
NIL
HORIZONTAL

SWITCH
356
213
488
246
debug-mode?
debug-mode?
0
1
-1000

INPUTBOX
40
127
116
187
full-population-size
16382.0
1
0
Number

INPUTBOX
116
127
190
187
sharers-only-size
1802.0
1
0
Number

SWITCH
46
94
187
127
full-population?
full-population?
1
1
-1000

TEXTBOX
22
74
250
102
Select Population size (full or sharers only)
11
0.0
1

SWITCH
624
116
762
149
proximity-risk?
proximity-risk?
0
1
-1000

SLIDER
601
197
796
230
total-interactions-per-day
total-interactions-per-day
0
10000
1802.0
1
1
NIL
HORIZONTAL

INPUTBOX
391
103
457
163
num-inner
223.0
1
0
Number

INPUTBOX
456
103
520
163
num-outer
1485.0
1
0
Number

TEXTBOX
378
86
465
104
Agents by group
11
0.0
1

INPUTBOX
669
363
734
423
inner-link
667.0
1
0
Number

INPUTBOX
737
363
800
423
outer-link
432.0
1
0
Number

INPUTBOX
698
231
774
291
inner-interactions-per-day
667.0
1
0
Number

INPUTBOX
330
103
391
163
num-core
94.0
1
0
Number

INPUTBOX
616
231
697
291
core-interactions-per-day
703.0
1
0
Number

TEXTBOX
620
102
770
120
Static vs Dynamic Neighbors
11
0.0
1

TEXTBOX
384
197
458
215
Model Testing
11
0.0
1

CHOOSER
13
323
199
368
sharing-rate-sensitivity-level
sharing-rate-sensitivity-level
"low" "baseline" "high"
0

TEXTBOX
47
309
197
327
Sharing rate sensitivity
11
0.0
1

INPUTBOX
603
364
666
424
core-link
703.0
1
0
Number

TEXTBOX
608
310
792
338
Fixed Model using links to form ties
11
0.0
1

TEXTBOX
616
183
792
211
Dynamic using interaction budget
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

The model explains the transmission of HCV among syringe-sharers. 

## HOW IT WORKS

The agents transmission mechanism depend on base infection rate (slider) and critical contact which depend on agent's number of syringes and it's risk factor within it's network

## HOW TO USE IT

The global variable consist of: 
1)initial number of HCV cases (seed infection cases): it can be adjusdted for different population.
2)Number of PWID depends on the model setup, the full population consist of both syringe-sharers and non-syringe sharers, but only syringe sharers takes part in trasnsmission in both cases. If we cosidering a setup with syrige-sharers only, we just ensure that number of PWID is the same as the total syringe-sharers.
3) Infection-rate refers to base infection rate (prevalence rate) in the case study of interest e.g we used HCV prevalence rate in Ireland in 2014 in this model.
4) our probability of syringe-sharing among PWID was also set based on a study in the Uk. It can be adjusted for another population
5) The total syringe sharers was computed based on Irish estimate
6) Clearing rate refers to natural clearance/ recovery from HCV infection
7)Rate at which agents who do not clear the infection initiate treatment.
8) Links represents agents interactions in this model, although agents weren't created as link node and the infection do not diffuse through the links but through actual syringe-sharing. This can also be adjusted to see the model outcomes based on varied number of links.
9) Treatment peer-effect is a parameter which suggest the influence of those who are currently on other infected agent
10) The switch was used for debugging to fix errors and abnormality in model behaviour.


## THINGS TO NOTICE
Two major outcomes were used for the model analysis:
1) Annual number of infection cases (it was calibrated and validated against real HCV cases in Ireland). It was also used to compare other heterogeneous model versions.
2)Transmission data which was used to estimate the basic reproduction number.

## THINGS TO TRY

1) use different infection and treatment rates
2) Try different number of links
3) Full population setup vs syringe-sharers only setup
4)Model sensitivity to syringe-sharing probability.

## EXTENDING THE MODEL

Heterogeneity in agents or network can be added and it's impact can be investigated

## NETLOGO FEATURES

The evaluation of treatment outcome was modelled as a daily check for consistency with the transmission processes.

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="for transmission" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="14320"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Calibration M1 experiment" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="14320"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="394"/>
      <value value="788"/>
      <value value="1575"/>
      <value value="3150"/>
      <value value="4725"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M1 experiment" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-new-infections</metric>
    <metric>annual-incidence-rate</metric>
    <metric>annual-prevalence-rate</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="14320"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="394"/>
      <value value="788"/>
      <value value="1575"/>
      <value value="3150"/>
      <value value="4725"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Num Run experiment" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="14320"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="4725"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M1 Validation" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="486"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="14320"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="4725"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M1 Calibration experiment" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-new-infections</metric>
    <metric>annual-incidence-rate</metric>
    <metric>annual-prevalence-rate</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="486"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="14320"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="4725"/>
      <value value="6300"/>
      <value value="7875"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment m1" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <metric>annual-prevalence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="4725"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment NM1" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <metric>annual-prevalence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="4725"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment M1 group" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <metric>annual-prevalence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="4725"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M11 experiment" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <metric>annual-prevalence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="4725"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M 11 experiment" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <metric>annual-prevalence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="4725"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cal experiment" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="394"/>
      <value value="788"/>
      <value value="1575"/>
      <value value="3150"/>
      <value value="4275"/>
      <value value="6300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="NFP Runs" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="3150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="14320"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="3150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="14320"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="sharer runs" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="3150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="G treatment sensitivity" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.4"/>
      <value value="0.45"/>
      <value value="0.5"/>
      <value value="0.55"/>
      <value value="0.6"/>
      <value value="0.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="3150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Real val" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="486"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="3150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="sensitivity" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="3150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.4"/>
      <value value="0.45"/>
      <value value="0.5"/>
      <value value="0.55"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M1 Cal" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="394"/>
      <value value="788"/>
      <value value="1575"/>
      <value value="3150"/>
      <value value="4275"/>
      <value value="6300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M1 Cal full" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="394"/>
      <value value="788"/>
      <value value="1575"/>
      <value value="3150"/>
      <value value="4275"/>
      <value value="6300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="14300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="run" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="3150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="validation" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="486"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="3150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M1" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="3150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1575"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1575"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M1 full calibration" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="16382"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="451"/>
      <value value="901"/>
      <value value="1802"/>
      <value value="3604"/>
      <value value="5406"/>
      <value value="7208"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M1 sharer only Calibration" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="451"/>
      <value value="901"/>
      <value value="1802"/>
      <value value="3604"/>
      <value value="5406"/>
      <value value="7208"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="run number" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="cross val" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.4"/>
      <value value="0.45"/>
      <value value="0.5"/>
      <value value="0.55"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="last par cross val" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="val real data" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="486"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="syringe sensi" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0"/>
      <value value="0.025"/>
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.4"/>
      <value value="0.45"/>
      <value value="0.5"/>
      <value value="0.55"/>
      <value value="0.6"/>
      <value value="0.95"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="treatment sensitivity" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0"/>
      <value value="0.025"/>
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.4"/>
      <value value="0.45"/>
      <value value="0.5"/>
      <value value="0.55"/>
      <value value="0.6"/>
      <value value="0.95"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-pwids">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="cal prox M1 experiment" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharers-only-size">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="contact-radius">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="full-population-size">
      <value value="16382"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="full-population?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proximity-risk?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-interactions-per-day">
      <value value="451"/>
      <value value="901"/>
      <value value="1802"/>
      <value value="3604"/>
      <value value="5406"/>
      <value value="7208"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="prox experiment" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-incidence-rate</metric>
    <enumeratedValueSet variable="sharers-only-size">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="contact-radius">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="full-population-size">
      <value value="16382"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="full-population?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proximity-risk?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-interactions-per-day">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="M4 comparison experiment" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-new-infections</metric>
    <enumeratedValueSet variable="sharers-only-size">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="core-link">
      <value value="703"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-core">
      <value value="94"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outer-link">
      <value value="432"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inner-link">
      <value value="667"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing-inner">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="contact-radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-inner">
      <value value="223"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="full-population-size">
      <value value="16382"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="full-population?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proximity-risk?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inner-interactions-per-day">
      <value value="703"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing-core">
      <value value="0.33"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-interactions-per-day">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-outer">
      <value value="1485"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing-outer">
      <value value="0.036"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="core-interactions-per-day">
      <value value="94"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="stable vs dynamic experiment" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-total-cured</metric>
    <metric>annual-on-treatment</metric>
    <metric>annual-new-infections</metric>
    <enumeratedValueSet variable="sharers-only-size">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="core-link">
      <value value="703"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-core">
      <value value="94"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outer-link">
      <value value="432"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inner-link">
      <value value="667"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing-inner">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="contact-radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-inner">
      <value value="223"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="full-population-size">
      <value value="16382"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clearing-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="full-population?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-rate">
      <value value="0.13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proximity-risk?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inner-interactions-per-day">
      <value value="667"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-rate">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing-core">
      <value value="0.33"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-interactions-per-day">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-outer">
      <value value="1485"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-syringe-sharing-outer">
      <value value="0.036"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="treatment-peer-effect">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-syringe-sharers">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="core-interactions-per-day">
      <value value="703"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="new partnership sensitivity" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>annual-total-chronic</metric>
    <metric>annual-total-cured</metric>
    <metric>annual-on-treatment</metric>
    <metric>annual-new-infections</metric>
    <metric>annual-ever-treated</metric>
    <enumeratedValueSet variable="sharers-only-size">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="core-link">
      <value value="703"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected">
      <value value="985"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-core">
      <value value="94"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inner-link">
      <value value="667"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outer-link">
      <value value="432"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-rate-sensitivity-level">
      <value value="&quot;low&quot;"/>
      <value value="&quot;baseline&quot;"/>
      <value value="&quot;high&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-inner">
      <value value="223"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="full-population-size">
      <value value="16382"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-links">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug-mode?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="full-population?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proximity-risk?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inner-interactions-per-day">
      <value value="667"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-interactions-per-day">
      <value value="1802"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-outer">
      <value value="1485"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="core-interactions-per-day">
      <value value="703"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
