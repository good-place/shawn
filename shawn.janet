(def tick 0.0001)

(defn- watchable-error [watchable]
  (error (string "Watchable must be Event, Array of Events or Fiber. Got: " (type watchable))))

(def- Event
  @{:update (fn [_ state])
    :watch (fn [_ state stream] [])
    :effect (fn [_ state stream])})

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

(defn- process-fibers [self]
  (loop [p :in (self :fibers)]
    (when-let [res (case (fiber/status p)
                         :new (resume p)
                         :pending (resume p)
                         :alive nil
                         :dead nil)]
      (if (event? res) (:transact self res) (watchable-error res))))
  (update self :fibers |(filter (fn [p] (and (fiber? p) (not= :dead (fiber/status p)))) $)))

(defn- process-threads [self]
  (while (not (empty? (self :threads)))
    (let [[ok res] (protect (thread/receive 0))]
      (if ok
        (cond
         (event? res)
         (:transact self res)
         (and (indexed? res)
              (= (first res) :fin))
         (let [tid (last res)
               ti (find-index |(= (first $) tid) (self :threads))
               t (get-in self [:threads ti 1])]
           (:close t)
           (array/remove (self :threads) ti))
         (watchable-error res))))
         (os/sleep tick)))

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
     (array/push (self :stream) watchable)
     (and (indexed? watchable) (all event? watchable))
     (array/concat (self :stream) (reverse watchable))
     (or (fiber? watchable))
     (array/push (self :fibers) watchable)
     (= :core/thread (type watchable))
     (let [tid (string (math/ceil (os/clock))
                       (math/rng-int (math/rng)))]
       (:send watchable tid)
       (array/push (self :threads) [tid watchable]))
     (watchable-error watchable)))
  (:effect event (self :state) (self :stream))
  (:notify self)
  (:process-stream self)
  (:process-fibers self)
  (:process-threads self))


(defn- observe [self observer]
  (array/push (self :observers) observer))

(defn init-store [&opt state]
  (default state @{})
  @{:state state
    :old-state nil
    :stream @[]
    :fibers @[]
    :threads @[]
    :observers @[]
    :transact transact
    :process-stream process-stream
    :process-fibers process-fibers
    :process-threads process-threads
    :notify notify
    :observe observe})

