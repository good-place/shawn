(def- Event 
  @{:update (fn update [_ state])
    :watch (fn watch [_ state stream] [])
    :effect (fn effect [_ state stream])})

(defn event? [e]
  (and (dictionary? e)
       (e :update)
       (e :watch)
       (e :effect)))

(defn make-event 
  "Creates new event"
  [{:update update-fn :watch watch-fn :effect effect-fn}]
  (def tab @{})
  (when update-fn (put tab :update update-fn))
  (when watch-fn (put tab :watch watch-fn))
  (when effect-fn (put tab :effect effect-fn))
  (table/setproto tab Event))

(defmacro defevent "Creates new named event"
  [name fns]
  ~(def ,name (,make-event ,fns)))

(defn- process-stream [self]
  (while (not (empty? (self :stream)))
    (:transact self (array/pop (self :stream)))))
 
(defn- process-pending [self]
  (loop [p :in (self :pending)]
    (let [res (case (fiber/status p)
                :new (resume p)
                :pending (resume p)
                :alive nil
                :dead nil)]
      (when (event? res) (update self :stream |(array/push $ res)))))
  (update self :pending |(filter (fn [f] (not= :dead (fiber/status f))) $))
  (:process-stream self))

(defn- notify [self]
  (unless (deep= (self :old-state) (self :state))
    (each o (self :observers) 
      (o (self :old-state) (self :state)))))

(defn- transact [self event] 
  (when (not (event? event)) (error "Only Events are transactable"))
  (put self :old-state (table/clone (self :state)))
  (:update event (self :state))
  (let [watchable (:watch event (self :state) (self :stream))]
    (cond
      (event? watchable)
      (update self :stream |(array/push $ watchable))
      (and (indexed? watchable) (all event? watchable))
      (update self :stream |(array/concat $ (reverse watchable)))
      (fiber? watchable)
      (update self :pending |(array/push $ watchable))
      (error (string "Watchable must be Event, Array of Events or Fiber. Got: " (type watchable)))))
  (:effect event (self :state) (self :stream))
  (:notify self)
  (:process-stream self)
  (:process-pending self))

(defn- transact-all [self & events]
  (each event events (:transact self event)))

(defn- observe [self observer]
  (array/push (self :observers) observer))

(def Store 
  @{:state @{}
    :olf-state @{}
    :stream @[]
    :pending @[]
    :observers @[]
    :transact transact
    :transact-all transact-all
    :process-stream process-stream
    :process-pending process-pending
    :notify notify
    :observe observe})

