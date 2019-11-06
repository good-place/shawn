(def- Event 
  @{:update (fn update [_ state] identity)
    :watch (fn watch [_ state stream] [])
    :effect (fn effect [_ state stream])})

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

(defn- purge-stream [self]
  (while (not (empty? (self :stream)))
    (:transact self (array/pop (self :stream)))))
 
(defn- purge-pending [self]
  (loop [p :in (self :pending)]
    (let [res (case (fiber/status p)
                :new (resume p)
                :pending (resume p)
                :dead nil)]
      (when (dictionary? res) (update self :stream |(array/push $ res)))))
  (update self :pending |(filter (fn [f] (= :pending (fiber/status f))) $))
  (:purge-stream self))

(defn- notify [self]
  (unless (deep= (self :old-state) (self :state))
    (each o (self :observers) 
      (o (self :old-state) (self :state)))))

(defn- transact [self event] 
  (put self :old-state (table/clone (self :state)))
  (:update event (self :state))
  (:notify self)
  (let [watchable (:watch event (self :state) (self :stream))]
    (cond (indexed? watchable)
          (update self :stream |(array/concat $ (reverse watchable)))
          (dictionary? watchable)
          (update self :stream |(array/push $ watchable))
          (fiber? watchable)
          (update self :pending |(array/push $ watchable))))
  (:effect event (self :state) (self :stream))
  (:purge-stream self)
  (:purge-pending self))

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
    :purge-stream purge-stream
    :purge-pending purge-pending
    :notify notify
    :observe observe})

