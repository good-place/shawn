(def Event
  "Event prototype used for creating events. It has three methods:\n
   :update method receives Store and State.
   Both are mutable, but Store mutation is very bad antipattern. Return value is ignored.\n
   :watch method receives Store, State and Stream.
   All thre are mutable, but Store and State mutation is very bad antipattern.
   Return value is pushed into stream for later processing.
   Throws when return value is not Event, Array of Events, Fiber or Thread\n
   :effect method receives Store, State and Stream. Its main purpose is to trigger side-effects.
   All thre are mutable, but Store and State mutation is very bad antipattern.
   Return value is ignored."
  @{:update (fn [store state])
    :watch (fn [store state stream] [])
    :effect (fn [store state stream])})

(defn valid?
  "Returns true if event is valid Event.
   Valid Event must be a table and have :update, :watch and :effect methods present."
  [event]
  (truthy?
    (and (table? event)
         (event :update)
         (event :watch)
         (event :effect))))

(defn make
  "Creates new anonymous Event. Useful for dynamically created Events. \n
   It has one parameter which is the table with :update, :watch and :effect methods.
   All of them can be nil."
  [fns-table]
  (-> @{} (table/setproto Event) (merge-into fns-table)))

(defmacro defevent
  "Macro that creates new named Event. Useful for statically created Events.\n
   It has two parameters:\n
   name: desired name for the Event. Preferably in PascalCase.\n
   fns: table with methods. Same as for make function."
  [name fns]
  ~(def ,name (,make ,fns)))
