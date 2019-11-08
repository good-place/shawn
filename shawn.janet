(defn- watchable-error [watchable]
  (error (string "Watchable must be Event, Array of Events or Fiber. Got: " (type watchable))))

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
    (when-let [res (case (fiber/status p)
                      :new (resume p)
                      :pending (resume p)
                      :alive nil
                      :dead nil)]
      (if (event? res) 
        (:transact self res)
        (watchable-error res))))
  (update self :pending |(filter (fn [f] (not= :dead (fiber/status f))) $)))

(defn- notify [self]
  (unless (deep= (self :old-state) (self :state))
    (each o (self :observers) 
      (o (self :old-state) (self :state)))))

(defn- transact [self event] 
  (unless (event? event) (error (string "Only Events are transactable. Got: " event)))
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
      (watchable-error watchable)))
  (:effect event (self :state) (self :stream))
  (:notify self)
  (:process-stream self)
  (:process-pending self))

(defn- observe [self observer]
  (array/push (self :observers) observer))

(defn init-store [&opt state]
  (default state @{})
  @{:state state
    :old-state nil
    :stream @[]
    :pending @[]
    :observers @[]
    :transact transact
    :process-stream process-stream
    :process-pending process-pending
    :notify notify
    :observe observe})

