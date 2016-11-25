;;; In-game integration support for Counter Strike: Global Offensive

;;add dummy data in case we join when the player is already dead
(define Csgo-cached_player {
  activity: "none"
  match_stats: {
    kills: 0
    deaths: 0
    assists: 0
    mvps: 0
  }
  state: {
    health: 0
    round_kills: 0
    round_killshs: 0
  }
  team: "CT"
  weapons: {}
})

(define Csgo-Weapons '(
  ("weapon_m4a1" "M4A4")
  ("weapon_m4a1_silencer" "M4A1-S")
  ("weapon_ak47" "AK47")
  ("weapon_aug" "AUG")
  ("weapon_awp" "AWP")
  ("weapon_bizon" "PP-Bizon")
  ("weapon_c4" "Bomb")
  ("weapon_deagle" "Deagle")
  ("weapon_decoy" "Decoy")
  ("weapon_elite" "Dualies")
  ("weapon_famas" "FAMAS")
  ("weapon_fiveseven" "FiveSeveN")
  ("weapon_flashbang" "Flash")
  ("weapon_g3sg1" "G3SG1")
  ("weapon_galilar" "Galil")
  ("weapon_glock" "Glock")
  ("weapon_hegrenade" "Grenade")
  ("weapon_hkp2000" "P2000")
  ("weapon_usp_silencer" "USP-S")
  ("weapon_incgrenade" "Incendiary")
  ("weapon_knife" "Knife")
  ("weapon_knife_t" "Knife") ;; T-side knife
  ("weapon_m249" "M249")
  ("weapon_mac10" "MAC-10")
  ("weapon_mag7" "MAG-7")
  ("weapon_molotov" "Molotov")
  ("weapon_mp7" "MP7")
  ("weapon_mp9" "MP9")
  ("weapon_negev" "Negev")
  ("weapon_nova" "Nova")
  ("weapon_p90" "P90")
  ("weapon_p250" "P250")
  ("weapon_cz75a" "CZ75")
  ("weapon_revolver" "R8")
  ("weapon_sawedoff" "Sawed-Off")
  ("weapon_scar20" "SCAR-20")
  ("weapon_sg556" "SG 553")
  ("weapon_smokegrenade" "Smoke")
  ("weapon_ssg08" "Scout")
  ("weapon_taser" "Zeus")
  ("weapon_tec9" "Tec-9")
  ("weapon_ump45" "UMP")
  ("weapon_xm1014" "XM1014")
  ; different knife models
  ("weapon_bayonet" "Bayonet")
  ("weapon_knife_flip" "Flip Knife")
  ("weapon_knife_gut" "Gut Knife")
  ("weapon_knife_karambit" "Karambit")
  ("weapon_knife_m9_bayonet" "M9 Bayonet")
  ("weapon_knife_push" "Shadow Daggers")
  ("weapon_knife_survival_bowie" "Bowie Knife")
  ("weapon_knife_tactical" "Huntsman Knife")
  ("weapon_knife_falchion" "Falchion Knife")
  ("weapon_knife_butterfly" "Butterfly Knife")
))

;;; function frame to be a proto for the json data packet
(define Csgo-Update {
  previous-phase: ""
  phase: ""

  new: (lambda (d)
         (functions*:! d self)
         d)

  health: (lambda () (health: (state: player)))

  armor: (lambda () (armor: (state: player)))

  helmet: (lambda () (helmet: (state: player)))

  ammo: (lambda ()
          (let* ((weapon (active-weapon))
                 (ammo-level (if (nil? weapon)
                                 0
                               (ammo-clip: weapon))))
            (/ ammo-level 30)))

  ;; returns the friendly name of the current weapon
  weapon-nice-name: (lambda ()
                     (let* ((weapon-slot (active-weapon))
                           (internal-name (if (notnil? weapon-slot) (name: (get-slot (weapons: player) weapon-slot))))
                           (actual-name (cadr (find (lambda (w) (eq? (car w) internal-name))
                                               Csgo-Weapons))))
                      (if (notnil? actual-name)
                        actual-name
                        (string-capitalize (if (string-prefix? "weapon_" internal-name)
                              (substring internal-name 7 (string-length internal-name))
                              internal-name)))))

  ;;returns the key of the active weapon, or nil if none are active
  active-weapon: (lambda ()
                   (define (is-active? w)
                       (or (eq? (state: w) "active")
                           (eq? (state: w) "reloading")))
                   (let* ((weapons (weapons: (player: self))))
                     (do ((weapon-keys (frame-keys weapons) (cdr weapon-keys)))
                         ((or (nil? weapon-keys)
                              (is-active? (get-slot weapons (car weapon-keys))))
                          (car weapon-keys)))))

  refresh-weapon-info: (lambda (weapon-name prev-data)
                  (let* ((weapon-info (get-slot (weapons: player) weapon-name))
                        (bullets (if (and (not (nil? weapon-info))
                                          (ammo_clip:? weapon-info))
                                     (ammo_clip: weapon-info)
                                     nil))
                        (percent-full (if (or (nil? bullets) (not (has-slot? weapon-info ammo_clip_max:)))
                                          0
                                          (/ (* bullets 100) (ammo_clip_max: weapon-info))))
                        (prev-weapon (if (notnil? prev-data) (get-slot-or-nil (weapons: prev-data) weapon-name) nil))
                        (weapon-state (state: weapon-info))
                        (prev-weapon-state (if (notnil? prev-weapon) (get-slot-or-nil prev-weapon state:) nil))
                        (reloading (eq? weapon-state "reloading"))
                        (done-reloading (and (eq? prev-weapon-state "reloading") (eq? weapon-state "active")))
                        (is-grenade (eq? (type: weapon-info) "Grenade"))
                        (is-weapon-switched (if (notnil? prev-data) (find (lambda (weapon-name)
                                                                            (let ((new-weapon-state (get-slot-or-nil (get-slot (weapons: prev-data) weapon-name) state:)))
                                                                                   (eq? new-weapon-state "holstered")))
                                                                          (frame-keys (weapons: prev-data)))  #f)))
                    (handle-event "UPDATE-AMMO" {value: percent-full bullet-count: bullets frame: self})
                    (handle-event "UPDATE-RELOADING" {value: (if reloading 1 0) frame: self})
                    (handle-event "UPDATE-RELOADING_DONE" {value: (if done-reloading 1 0) frame: self})
                    ; a user can switch weapons twice in a row so the weapon_switched event won't reset, so we have to do it this way
                    (if is-grenade
                      ;; in order to trigger the event again when going from grenade-to-grenade, set it to 0 first
                      (begin
                        (handle-event "UPDATE-HOLDING_GRENADE" {value: 0 frame: self})
                        (handle-event "UPDATE-HOLDING_GRENADE" {value: 1 frame: self}))
                      (handle-event "UPDATE-HOLDING_GRENADE" {value: 0 frame: self}))
                    (when is-weapon-switched
                      (handle-event "UPDATE-WEAPON_SWITCHED" {value: 0 frame: self})
                      (handle-event "UPDATE-WEAPON_SWITCHED" {value: 1 frame: self}))))

  update: (lambda ()
            (define (wasnt-playing)
              (and (neq? previous-phase "live")
                   (neq? previous-phase "freezetime")))

            (define (now-playing)
              (or (eq? phase "live")
                  (eq? phase "freezetime")))

            (define (freezetime-ended)
              (and (eq? phase "live")
                   (eq? previous-phase "freezetime")))

            (let ((is-actual-player (eq? (steamid: provider) (steamid: player))))
              ;; track round phase shanges
              (when (round:? self)
                    (previous-phase:! functions* phase)
                    (phase:! functions* (phase: round)))

              ;; don't use the supplied "player" when the player data isn't the one in the provider (aka: we're spectating)
              ;; otherwise cache it for later
              (if is-actual-player
                (set! Csgo-cached_player player)
                (player:! self Csgo-cached_player))

              ;; fix round number to not be base 0 and to update when freezetime starts instead of when the round ends
              (when (neq? phase "over")
                (round:! (map: self) (succ (round: (map: self)))))

              (cond
              ;; detect new round from phase transitions
              ((and (wasnt-playing)
                    (now-playing))
                (new-round #t))
              ;; player update
              ((eq? (activity: player) "playing")
                ;; Check if player update is needed
                (when (and is-actual-player
                         (previously:? self)
                         (player:? previously))
                    (let ((player-data (player: previously)))
                            ;; state update
                            (when (state:? player-data)
                                (let* ((keys-to-update (frame-keys (state: player-data))))
                                  (map (lambda (k)
                                         (let* ((value (get-slot (state: player) k))
                                               (update-cmd (string-upcase (str "update-" (string-trim (str k) ":")))))
                                           (handle-event update-cmd {value: value frame: self})))
                                       keys-to-update)))
                            ;; weapon/ammo update
                            (when (weapons:? player-data)
                                  (map (lambda (weapon-name)
                                         (when (eq? (active-weapon) weapon-name)
                                             (refresh-weapon-info weapon-name player-data)))
                                       (frame-keys (weapons: player-data)))
                                  (let ((dropped-bomb (find (lambda (weapon-name)
                                                              (let ((weapon (get-slot (weapons: player-data) weapon-name)))
                                                                (== (get-slot-or-nil weapon type:) "C4")))
                                                       (frame-keys (weapons: player-data)))))
                                       (when dropped-bomb
                                         (handle-event "UPDATE-BOMB_DROPPED" {value: 0 frame: self})
                                         (handle-event "UPDATE-BOMB_DROPPED" {value: 1 frame: self}))))

                            ;; match stats update
                            (when (match_stats:? player-data)
                                (let* ((keys-to-update (frame-keys (match_stats: player-data))))
                                  (map (lambda (k)
                                         (let* ((value (get-slot (match_stats: player) k))
                                               (update-cmd (string-upcase (str "match-update-" (string-trim (str k) ":")))))
                                            (handle-event update-cmd {value: value frame: self})))
                                        keys-to-update)))))

                (when (and is-actual-player
                         (added:? self)
                         (player:? added))
                    (let ((player-data (player: added)))

                      ;; weapons added
                      (when (weapons:? player-data)
                        (map (lambda (weapon-name)
                               (when (eq? (active-weapon) weapon-name)
                                   (refresh-weapon-info weapon-name nil))
                               (let ((weapon-info (get-slot (weapons: player) weapon-name)))
                                  (when (== (get-slot-or-nil weapon-info type:) "C4")
                                    (handle-event "UPDATE-BOMB_PICKED_UP" {value: 0 frame: self})
                                    (handle-event "UPDATE-BOMB_PICKED_UP" {value: 1 frame: self}))))
                             (frame-keys (weapons: (if (! (frame? (weapons: player-data))) player player-data)))))))

                ;; detect freezetime ending
                (when (freezetime-ended)
                  (handle-event "UPDATE-ROUND_START" {value: 0 frame: self})
                  (handle-event "UPDATE-FREEZETIME_ENDED" {value: 1 frame: self}))

                ;; if in "over" state, dispatch event for end of round
                (when (eq? phase "over")
                  (handle-event "UPDATE-FREEZETIME_ENDED" {value: 0 frame: self})
                  (handle-event "UPDATE-ROUND_OVER" {value: 1 frame: self}))))))


  add-flash: (lambda (raw-color)
               (blend raw-color white-color (/ (* (flashed: (state: player)) 100) 256)))

  reset-nonhealth-indicators: (lambda ()
                                (write-log-if-debug-logging-enabled "")
                                (write-log-if-debug-logging-enabled "==> You have died.")
                                (write-log-if-debug-logging-enabled "")
                                (map (lambda (event)
                                       (write-log-if-debug-logging-enabled (str "resetting " event))
                                       (handle-event (str "UPDATE-" event) {value: 0 frame: self}))
                                     '("ARMOR" "ROUND_KILLS" "ROUND_KILLHS" "FLASHED"))
                                (handle-event "UPDATE-HELMET" {value: #f frame: self})
                                (handle-event "UPDATE-AMMO" {value: 0 bullet-count: 0 frame: self})
                                (handle-event "UPDATE-DEAD" {value: 1 frame: self}))

  new-round: (lambda (refresh-health)
               (write-log-if-debug-logging-enabled "")
               (write-log-if-debug-logging-enabled (str "==> Start of a new round - from " (if refresh-health "phase change" "health reset")))
               (write-log-if-debug-logging-enabled "")
               (if refresh-health (handle-event "UPDATE-HEALTH" {value: 100 frame: self skip-round-check: #t}))
               (handle-event "UPDATE-ARMOR" {value: (send self armor:) frame: self})
               (handle-event "UPDATE-HELMET" {value: (send self helmet:) frame: self})
               (handle-event "UPDATE-ROUND_KILLS" {value: 0 frame: self})
               (handle-event "UPDATE-ROUND_KILLHS" {value: 0 frame: self})
               (handle-event "UPDATE-FLASHED" {value: 0 frame: self})
               (handle-event "UPDATE-DEAD" {value: 0 frame: self})
               (handle-event "UPDATE-ROUND_OVER" {value: 0 frame: self})
               (when (and (eq? previous-phase "over")
                        (eq? phase "freezetime"))
                        (handle-event "UPDATE-ROUND_START" {value: 1 frame: self}))
               (when (notnil? (active-weapon)) (refresh-weapon-info (active-weapon) nil)))

  })

;;; handlers

(handler "STATE-UPDATE"
         (lambda (data)
           (let* ((player-data (player: data)))
             (cond ((and (state:? player-data) (team:? player-data))
                    (send Generic-Initializer initialize: #t "CSGO")
                    (write-log-if-debug-logging-enabled "CSGO state update event data: " data)
                    (send (send Csgo-Update new: data) update:))
                   ((and (activity:? player-data)
                         (eq? (activity: player-data) "menu"))
                    (send Generic-Initializer deinitialize:))))))

(handler-with-post-event "UPDATE-HEALTH" (lambda (data) '()))

(handler "POST-UPDATE-HEALTH"
          (lambda (data)
            (let* ((health (value: data))
                 (data-frame (frame: data)))
             ;(write-log-if-debug-logging-enabled (str "Handling POST-UPDATE-HEALTH event"))
             (if (and (not (skip-round-check:? data))
                      (eq? health 100))
                 (send data-frame new-round: #f))
             (if (eq? health 0)
                 (send data-frame reset-nonhealth-indicators:)))))

(handler-with-post-event "UPDATE-FLASHED" (lambda (data) '()))

(handler "POST-UPDATE-FLASHED"
         (lambda (data)
            ; Clamp 0-255 value to new event in 0-100 percentage range
            (let* ((flash_raw (value: data)))
              (handle-event "UPDATE-FLASHED_PERCENT" {value: (integer (/ flash_raw 2.55))}))))

(handler-with-post-event "UPDATE-ROUND_KILLS" (lambda (data) '()))

(handler "POST-UPDATE-ROUND_KILLS"
         (lambda (data)
           (handle-event "UPDATE-ROUND_KILLS_HEADSHOTS_COMBO" data)))

(handler-with-post-event "UPDATE-HELMET" (lambda (data) '()))

(handler "POST-UPDATE-HELMET"
         (lambda (data)
           (let* ((value (value: data))
                  (numeric_value (if value 1 0)))
             (handle-event "UPDATE-HELMET_NUMERIC" {value: numeric_value})
           )))

(handler "UPDATE-ROUND_KILLS_HEADSHOTS_COMBO"
         (lambda (data)
           (let* ((kills (value: data))
                 (headshots (min (list
                              5
                              kills
                              (if (round_killhs:? (state: (player: (frame: data))))
                                (round_killhs: (state: (player: (frame: data))))
                                0))))
                 (non-headshots (min (list (- 5 headshots) (- kills headshots))))
                 (no-hits (max (list 0 (- 5 kills))))
                 (colors (append (make-list headshots red-color)
                                 (make-list non-headshots white-color)
                                 (make-list no-hits black-color))))
             (write-log-if-debug-logging-enabled (str "Updating kills to " kills " with " headshots " headshots"))
             (on-device 'rgb-per-key-zones show-on-keys: (interval 0xE9 0xED) colors))))

(add-event-per-key-zone-use "UPDATE-ROUND_KILLS_HEADSHOTS_COMBO" "macro-keys")
(event-autoinit-exclusion '("STATE-UPDATE"))
