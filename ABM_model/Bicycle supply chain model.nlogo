extensions [matrix]

globals [
  total_expenditures
  order_count
  contract_value_mil
  total_availability_bicycles
  list_new_demand
  list_all_order_values
  list_total_orders
  list_end-user_orders
  list_facility_company_orders
  list_supplier_orders
  list_order_waiting_time
  matrix_list
  order_matrix
  year
  total_bike_demand
  military_branches
  initial_total_bicycles
]

breed [facility_companies facility_company]
breed [end-users end-user]
breed [suppliers supplier]
breed [finance_and_controls finance_and_control]
breed [bicycles bicycle]
breed [managers manager]

facility_companies-own [
  name
  effort
  order_list
  expenditures_current_year
  expenditure_daily
  expenditure_daily_list
  budget_left
  budget
  budget_critical?
  help_needed
]

finance_and_controls-own [
  effort
]

end-users-own [
  name
  effort
  bicycles_in_possession ;set of breed bicycles
  bicycles_to_be_replaced
  demand ;amount of bikes they want to keep in posession
  new_demand ;amount of bikes needed for employees that haven't had a bike before.
  net_demand
  order
  facility_company_region
  military_branche
  willingness_to_share
]

suppliers-own [
  current_model
  price
  order_list ;set of breed facility-companies that have orders themselves and made connection with facility company.
  stock
]

bicycles-own [
  creation_tick
  state ; poor state will require maintenance
  model ; an older model is less satisfactory
  price
]

managers-own [
  effort
  times_said_no
  total_declined_demand
]

undirected-link-breed [information-links information-link]   ;color 9
directed-link-breed [material-links material-link]         ;color 15
undirected-link-breed [budgetary-links budgetary-link]       ;color 105

;;;;;;;;;;;;;;;SETUP;;;;;;;;;;;;;;;;;;;
To Setup
  clear-all
  reset-ticks

  import-pcolors "kaartvnl.png"

  set year 1

  set military_branches (list "Marine" "Landmacht" "Luchtmacht" "KMar")

  ;turtle creation
  create-suppliers 1 [
    setxy -30 30
    set size 5 set color 5
    set shape "box"
    set current_model 1
    set stock 1000
    set price price_per_bike
    set order_list []
  ]

  create-finance_and_controls 1 [
    setxy -40 40
    set size 8 set shape "euro"
    set heading 0
  ]

  ;havelte, Schaarsbergen, Breda, Den Helder, Den Haag, Soesterberg and oirschot
  ;0:name, 1:coordinate x, 2:cordinate y, 3:number of orders, 4:number of locations supplying
  let list_facility_companies (list
    (list "Havelte" 17 20 37 4)
    (list "Schaarsbergen" 14 -6 79 8)
    (list "Breda" -13 -20 48 3 3)
    (list "Den Helder" -10 28 54 3)
    (list "Den Haag" -21 -5 3 3)
    (list "Soesterberg" 0 0 19 6)
    (list "Oirschot" 2 -23 26 5)
  )

  foreach list_facility_companies [a ->
    create-facility_companies 1 [
      set name word "facility_company " who
      setxy item 1 a  item 2 a
      set label item 0 a set label-color 125
      set shape "house" set size 2 + round(budget / 20000) set color 62
      set order_list []
      set expenditure_daily_list []
      set budget_critical? false
      set expenditure_daily 0
    ]
  ]

  create-managers 1 [
    setxy -30 40
    set size 5 set color 45 set shape "person"
    set effort 0
    set times_said_no 0
    set total_declined_demand 0
  ]

  create-end-users 144 [
    set name word "end-user " who
    let patchnl one-of patches with [pcolor = 7.8 and count turtles-here = 0]
    setxy [pxcor] of patchnl [pycor] of patchnl
    set size 3
    set color 64
    set order []
    set military_branche one-of military_branches
    (ifelse general_willingness_to_share = 1 [
      set willingness_to_share random 5
      ]
      general_willingness_to_share = 2 [
        set willingness_to_share 5 + random 10
      ] [
        set willingness_to_share 10 + random 10
    ])
    ;create demand for end-users with conditions on bicycles in posession and chance
    let who_sequence who - min [who] of end-users
    let chance who_sequence / count end-users

      (ifelse chance <= 0.3 [
        set demand 1 ;par
        ]
        chance <= 0.6 [
          set demand 2
        ]
        chance <= 0.8 [
          set demand 2 + random 3
        ]
        chance <= 0.95 [
          set demand 5 + random 25
        ]
        chance <= 1 [
          set demand 100 + random 100
      ])
    set demand demand * initial_amount_of_bicycles
  ]

  foreach [who] of end-users [ a ->
    create-bicycles round (([demand] of end-user a) * ((100 - random share_demand_malfunctioning) / 100)) [
      set shape "bicycle" set size 4 set color 17
      setxy [xcor] of end-user a [ycor] of end-user a
      set model [current_model] of supplier 0 - 1
      set state random ( ticks_in_year )
    ]
  ]

  ask end-users [
    set bicycles_in_possession bicycles with [xcor = [xcor] of myself and ycor = [ycor] of myself]
  ]

  set list_total_orders []
  set list_end-user_orders []
  set list_facility_company_orders []
  set list_supplier_orders []
  set list_order_waiting_time []
  set list_all_order_values []
  set list_new_demand []
  set initial_total_bicycles count bicycles


  ;procedures
  create_links ;set undircted links from end-user to nearest facility company
               ;create_regions

  ask end-users [set facility_company_region [who] of one-of information-link-neighbors]

  ;scale the budget on the emount of end users linked to that facility company
  ask facility_companies [
    set budget round (facility_companies_budget_yearly_total * (sum [demand] of end-users with [facility_company_region = [who] of myself] / sum [demand] of end-users))
  ]
end

;;;;;;;;;;;;;GO;;;;;;;;;;;;;;;;

to go
  update_demand
  end_users_process
  facility_company_process
  supplier_process
  manager_function
  finance-and-control_process
  predictive_replacement_policy
  improved_information_provision_policy
  bicycle_degradation
  resets
  tick
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; SETUP SUBROUTINES ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to create_regions
  ask patches [
    set pcolor [who] of min-one-of facility_companies [distance myself] * 10
  ]
end

to create_links
  ask end-users [
    create-material-link-from supplier 0 [set color 15]
    create-information-link-with min-one-of facility_companies [distance myself] [set color 46]
  ]

  ask facility_companies [
    create-information-link-with supplier 0 [set color 46]
  ]

  ask material-links [hide-link]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; GO SUBROUTINES ;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update_demand
  if yearly_demand_growth > 0 and year > burn-in_period [
    let growth round( 100 / ((1 + yearly_demand_growth / 100) ^ year - 1) )
    ask end-users [
      if random ticks_in_year = 1 and new_demand = 0 [
        let chance random growth
        (ifelse chance <= 30 [
          set new_demand 1
          set demand demand + new_demand
          ]
          chance <= 60 [
            set new_demand 2
            set demand demand + new_demand
          ]
          chance <= 80 [
            set new_demand 2 + random 3
            set demand demand + new_demand
          ]
          chance <= 95 [
            set new_demand 5 + random 25
            set demand demand + new_demand
          ]
          chance <= 100 [
            set new_demand 30 + random 170
            set demand demand + new_demand
        ])
      ]

      if new_demand > 0 [
        set list_new_demand lput new_demand list_new_demand
      ]
      set new_demand 0
    ]
  ]
end

to end_users_process
  let current_supplier_model ([current_model] of supplier 0)

  ask end-users [
    set bicycles_in_possession bicycles with [xcor = [xcor] of myself and ycor = [ycor] of myself]

    if net_demand = 0 [
      set bicycles_to_be_replaced turtle-set nobody

      ;replace bikes if new model is out and if they are bicycle_average_lifetime_years +1 years old.
      set bicycles_to_be_replaced bicycles_in_possession with [ticks - creation_tick > ticks_in_year * (bicycle_average_lifetime_years + 1) and model < current_supplier_model]

      if count bicycles_in_possession with [state < ticks_in_year / 4 ] + (demand - count bicycles_in_possession) >= (share_demand_malfunctioning / 100) [
        set bicycles_to_be_replaced bicycles_in_possession with [state < ticks_in_year / 4 ]
        set net_demand demand - count bicycles_in_possession
        ;checking which bicycles need replacement takes effort.
        set effort effort + 1
      ]
      set net_demand net_demand + count bicycles_to_be_replaced

    ]

    (ifelse order = [] and net_demand > 0 [

      let waiting_time round(5 * (demand / 200))
      let date ticks
      let justification initial_justification
      let total_price net_demand * price_per_bike

      ;create [order] as list -> order structure: [
      ;0 order_number,
      ;1 who_number of end-user i.e. the number of the original order creator,
      ;2 bike_model_number,
      ;3 quantity,
      ;4 price per bike,
      ;5 total price of order
      ;6 expected_delivery_waiting_time,
      ;7 justification
      ;8 date of creation on tick number
      ;9 end-user belonging to facility company region number

      set order lput order_count order
      set order lput who order
      set order lput current_supplier_model order
      set order lput net_demand order
      set order lput price_per_bike order
      set order lput total_price order
      set order lput waiting_time order
      set order lput justification order
      set order lput date order
      set order lput [who] of one-of information-link-neighbors order

      ;update the order matrix accordingly:
      set list_end-user_orders lput order_count list_end-user_orders
      ;create entries with 0 for facility company and supplier to fill
      set list_facility_company_orders lput 0 list_facility_company_orders
      set list_supplier_orders lput 0 list_supplier_orders
      set list_order_waiting_time lput 0 list_order_waiting_time

      set list_total_orders lput order list_total_orders

      ;providing justification adds to the effort made to place an order. There is more "bureaucracy" for the end-user so to say.
      set effort effort + round(justification / 10)

      set effort effort + 1 ;creating an order takes effort, according to the amount of information that needs manual entry.
                            ;(some entries are only for the model functioning and do not correspond to actions neede in the real world)

      ;keep track of global order count
      set order_count order_count + 1

    ] order != [] [
      let total_price item 5 order
      let oip_order_number item 0 order

      ;send order to supplier or facility company depending on the height of the order.
      (ifelse total_price <= order_value_limit_facco and
        not member? oip_order_number list_supplier_orders and
        not member? oip_order_number list_facility_company_orders [

          ask supplier 0 [
            set order_list lput [order] of myself order_list
          ]
          ask one-of information-link-neighbors [
            set expenditure_daily expenditure_daily + [total_price] of myself
          ]
          set effort effort + 1 ;sending order to supplier
        ]
        total_price > order_value_limit_facco and
        not member? oip_order_number list_supplier_orders and
        not member? oip_order_number list_facility_company_orders  [

          ask one-of information-link-neighbors [
            if length order_list < order_processing_capacity [
              set order_list lput [order] of myself order_list
            ]
          ]
          set effort effort + 1 ;sending order to facility company
      ])
    ])
  ]
end

to facility_company_process
  ask facility_companies [
    ;read the order that needs to be processed
    foreach order_list [ a ->

      ;oip = Order In Process
      let oip_order_number item 0 a
      let oip_who item 1 a
      let oip_model_number item 2 a
      let oip_quantity item 3 a
      let oip_price item 4 a
      let oip_total_price item 5 a
      let oip_waiting_time item 6 a
      let oip_justification item 7 a
      let oip_date item 8 a
      let oip_facility_company_who item 9 a

      ;update matrix with order in progress number
      set list_facility_company_orders replace-item oip_order_number list_facility_company_orders oip_order_number

      ;finance and control check with if statements ->
      if not member? oip_order_number list_supplier_orders and

      (budget_critical? = false and
        ((oip_total_price < order_value_limit_fc and oip_justification > 50) or
          (oip_total_price >= order_value_limit_fc and oip_justification >= 100)))
      or
      (budget_critical? = true and
        ((oip_total_price < order_value_limit_fc and oip_justification > 100) or
          (oip_total_price >= order_value_limit_fc and oip_justification >= 150))) [

        if budget_critical? = true [print "true"]

        ;add the order to the supplier order list
        ask supplier 0 [
          set order_list lput a order_list
        ]
        set effort effort + 1 ;sending order to supplier

        set expenditure_daily expenditure_daily + oip_total_price
      ]
    ]

    ;track expenditures


    let index_start (year - 1) * ticks_in_year
    let index_stop length expenditure_daily_list
    set expenditures_current_year sum sublist expenditure_daily_list index_start index_stop

    ;calculate the budget left at the facility company.
    set budget_left budget - expenditures_current_year

    ;rescale the size of the agent accoring to the budget left. More budget results in a bigger turtle size. Adds to visualisation.
    set size min (list (2 + round(budget_left / 20000)) 12 )
  ]
end

to supplier_process
  let processed_order_list []
  let total_value_of_bicycles_delivered 0

  ;read the orders in the order list of the supplier appended by the other agents.
  foreach [order_list] of supplier 0 [ a ->

    ;oip = Order In Process
    let oip_order_number item 0 a
    let oip_who item 1 a
    let oip_model_number item 2 a
    let oip_quantity item 3 a
    let oip_price item 4 a
    let oip_total_price item 5 a
    let oip_waiting_time item 6 a
    let oip_justification item 7 a
    let oip_date item 8 a
    let oip_facility_company_who item 9 a

    ;update the order matrix accordingly:
    set list_supplier_orders replace-item oip_order_number list_supplier_orders oip_order_number

    ;check if the stock is adequately filled to fulfill the order.
    if [stock] of supplier 0 >= oip_quantity [

      set total_value_of_bicycles_delivered total_value_of_bicycles_delivered + oip_total_price

      ;create the amount of bicycles at the locations of the agents created the orders.
      create-bicycles oip_quantity [
        let oip_xcor [xcor] of end-user oip_who
        let oip_ycor [ycor] of end-user oip_who
        set shape "bicycle" set size 4 set color 17
        set xcor oip_xcor set ycor oip_ycor
        set model [current_model] of supplier 0
        set creation_tick ticks

        ;set the state of the bicycle either 1 or a normal ditribution with the mean as specified in the
        ;slider in the interface with a standard deviation of half a year.
        set state max list 1 (random-normal (ticks_in_year * bicycle_average_lifetime_years) ticks_in_year)
      ]

      ;set the order of the end-user empty because the order is delivered
      ask end-user oip_who [
        set order []
        set net_demand 0
        ask bicycles_to_be_replaced [die]
      ]

      ;remove the order from the facility company list, as the order is fulfilled.
      ask facility_company oip_facility_company_who [
        set order_list remove a order_list
      ]

      ;remove the order from the supplier list because the order is delivered.
      ask supplier 0 [
        set order_list remove a order_list

        ;Subtract the delivered amount of bikes from the stock.
        set stock stock - oip_quantity
      ]

      ;update order matrix
      set list_order_waiting_time replace-item (oip_order_number) list_order_waiting_time (ticks - oip_date)
    ]
  ]
end

to bicycle_degradation
  ask bicycles [
    set state state - 365 / ticks_in_year
    if state = 0 [
      die ;the bike is total loss and dissapears from the model when maintenance state = 0
    ]
    if random (ticks_in_year * (count bicycles / 20)) = 1 [die] ;chance of losing a bicycle randomly
  ]
end

to finance-and-control_process
  ask finance_and_control 1 [

    let facility_companies_with_openstanding_orders facility_companies with [length order_list > 0]
    ;go to a random facility company to check the progress of that facility company.
    if count facility_companies_with_openstanding_orders > 0 [
      let facility_company_here one-of facility_companies_with_openstanding_orders
      ;relocate the the facility company in question to investigate the hurdles of the order.
      move-to facility_company_here

      let who-here [who] of facility_company_here

      ;investigate the facility companies budget limit
      let budget_here [budget] of facility_company_here
      let expenditures_here [expenditures_current_year] of facility_company_here
      let budget_left_here [budget_left] of facility_company_here



      (ifelse [budget_left] of facility_company_here / max list 1 [budget] of facility_company_here < critical_budget_left_share / 100 [
        ask facility_company_here [set budget_critical? true]
      ] [
        ask facility_company_here [set budget_critical? false]
      ])

      let a first [order_list] of facility_company_here

      ;read order of end-user with large purchasing order
      let oip_order_number item 0 a
      let oip_who item 1 a
      let oip_model_number item 2 a
      let oip_quantity item 3 a
      let oip_price item 4 a
      let oip_total_price item 5 a
      let oip_waiting_time item 6 a
      let oip_justification item 7 a
      let oip_date item 8 a
      let oip_facility_company_who item 9 a

      ;check for adequate budget, sufficient justification and contract fullfillment before allowing the big purchasing order.

      (ifelse oip_total_price > budget_left_here [
        ;print (word "order " a " is too large and will surpass the budget of facility company " facility_company who-here)
        ;Finance and control looks for budgets at other facility companiesin order to fullfill large orders that surpass the initial proposed budget for that specific facility company.
        ;calculate deficit in budget which is due to the large order
        let deficit oip_total_price - budget_left_here
        set effort effort + 1 ;for looking up budget information
        let added_budget 0

        ; look at which facility companies have excess budget
        if sum [budget_left] of facility_companies with [budget_left > 0] > deficit [
          while [added_budget < deficit] [
            ;take budget from other locations
            set effort effort + 1
            ask one-of facility_companies with [budget_left > 0] [
              let amount min (list (deficit - added_budget) budget_left)
              set added_budget added_budget + amount
              set budget budget - amount
            ]
          ]
          ;add budget to facility company in need, but not more than the order to be fulfilled requires.
          ask facility_company_here [
            set budget budget + added_budget
          ]
        ]
        ]
        oip_justification < 100 and not member? oip_order_number list_supplier_orders [
          ;gather more information on justification, or why the order is so high. For this, assume more effort put in by both the facility company and finance and control.
          ;gather justification stepwise, but simplify through adding effort to finance and control that will ensure budget gets realized.
          ask facility_company_here [
            ;add justification according to the end-users willingness to share argumentation on their orders.
            set a replace-item 7 a (oip_justification + [willingness_to_share] of end-user oip_who)
            set order_list replace-item 0 order_list a
          ]
          set effort effort + 1
      ])
    ]
  ]
end

to manager_function
  let fac_comps_openstanding_orders facility_companies with [length(order_list) > 0]

  ask one-of managers [
    if count fac_comps_openstanding_orders > 0 [
      let fac_comp one-of fac_comps_openstanding_orders
      foreach [order_list] of fac_comp [a ->
        let oip_order_number item 0 a
        let oip_who item 1 a
        let oip_model_number item 2 a
        let oip_quantity item 3 a
        let oip_price item 4 a
        let oip_total_price item 5 a
        let oip_waiting_time item 6 a
        let oip_justification item 7 a
        let oip_date item 8 a
        let oip_facility_company_who item 9 a

        move-to end-user oip_who

        if ([expenditures_current_year] of facility_company oip_facility_company_who) / max (list 1 [budget] of facility_company oip_facility_company_who) > 1.05 [
          ask end-user oip_who [
            set order []
            set demand demand - oip_quantity
            set net_demand 0
          ]

          ;remove the order from the facility company list, as the order cannot be fulfilled.
          ask facility_company oip_facility_company_who [
            set order_list remove a order_list
            set expenditure_daily expenditure_daily - oip_price
          ]

          ;remove the order from the supplier list because the order cannot be fulfilled.
          ask supplier 0 [
            set order_list remove a order_list
          ]

          set effort effort + 1 ;cnacelling an order
          set times_said_no times_said_no + 1
          set total_declined_demand total_declined_demand + oip_quantity

        ]
      ]
    ]
  ]
end

to resets
  if length list_end-user_orders > 0 [
    set matrix_list (list list_end-user_orders list_facility_company_orders list_supplier_orders list_order_waiting_time)
    set order_matrix matrix:from-column-list matrix_list
    ;print matrix:pretty-print-text order_matrix
  ]

  if ticks mod ticks_in_year = 0  and ticks > 1 [
    set year year + 1
    ask facility_companies [
      set budget round (facility_companies_budget_yearly_total * (count end-users with [facility_company_region = [who] of myself] / count end-users))
      set budget_left budget
    ]
  ]

  if ticks mod (ticks_in_year * 4) = 0  and ticks > 1 [
    ask supplier 0 [
      set current_model current_model + 1
    ]
  ]

  ask supplier 0 [
    ;the supplier only manufactures a certain model of bikes for a limited amount of time due to production lock-in.
    ;Switching model-production takes considerable effort and there is no way to simulataneously produce varying models of bikes. Only producing 1 model at a time.
    if stock < max_supplier_stock and ticks mod ticks_in_year >= 0 and ticks mod ticks_in_year <= ticks_in_year / 12 * manufacturing_cycle  [
      set stock stock + production_rate
    ]
  ]

  ask facility_companies [
    set expenditure_daily_list lput expenditure_daily expenditure_daily_list
    set expenditure_daily 0
  ]
  set total_availability_bicycles sum [count bicycles_in_possession] of end-users / sum [demand] of end-users * 100
end


to predictive_replacement_policy
  ;This policy involves the replacement of bicycles once a year that are in need of maintenance. The goal is to decrease
  ;the amount of very large orders and thereby decreasing the effort load on the finance and control and facility company
  ;agents.

  if predictive_replacements = true and ticks mod ticks_in_year = 0 [
    let maintenance_bikes 0

    ask facility_companies [

      set maintenance_bikes [bicycles_in_possession with [state < ticks_in_year / 2] ] of information-link-neighbors with [breed != suppliers]
      set effort effort + 1
      foreach maintenance_bikes [bike ->
        if count bike > 0 [
          if [stock] of supplier 0 >= count bike [
            ask supplier 0 [set stock stock - count bike]
            ask bike [set state max list 1 (random-normal ( ticks_in_year * bicycle_average_lifetime_years) ticks_in_year)]
            set expenditure_daily expenditure_daily + count bike * price_per_bike


          ]
        ]
      ]

    ]
  ]
end

to improved_information_provision_policy
  if improved_information_provision = true [

  ]
end




;data gathering and outputs for the EMA workbench:

to-report effort_end-users
  report sum [effort] of end-users
end

to-report effort_facility_companies
  report sum [effort] of facility_companies
end

to-report effort_finance_and_control
  report [effort] of finance_and_control 1
end

to-report effort_manager
  report [effort] of one-of managers
end

to-report times_said_no_manager
  report [effort] of one-of managers
end

to-report demand_end-users
  report sum [demand] of end-users
end

to-report orders_waiting_time
  (ifelse length list_order_waiting_time != 0 [
    report sum list_order_waiting_time / length list_order_waiting_time
  ] [
    report 0
  ])
end

to-report budget_exceedance
  let facility_companies_with_exceeded_budget facility_companies with [expenditures_current_year > budget]
  (ifelse any? facility_companies_with_exceeded_budget [
    report sum [expenditures_current_year - budget] of facility_companies_with_exceeded_budget
  ] [
    report 0
  ])
end

;check percentage of new_demand created:
;sum list_new_demand / initial_total_bicycles
@#$#@#$#@
GRAPHICS-WINDOW
240
12
687
460
-1
-1
4.35
1
10
1
1
1
0
0
0
1
-50
50
-50
50
0
0
1
ticks
30.0

BUTTON
15
13
81
46
Setup
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
670
653
879
686
price_per_bike
price_per_bike
100
1000
260.0
5
1
euros
HORIZONTAL

BUTTON
89
13
152
46
Go
Go
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
160
13
224
46
Go once
Go
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
706
13
912
163
Total expenditures of facility companies
ticks
euro's
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"total budgets" 1.0 0 -7500403 true "" "plot sum [budget_left] of facility_companies"

SLIDER
464
619
655
652
facility_companies_budget_yearly_total
facility_companies_budget_yearly_total
100000
1000000
500000.0
50000
1
euros
HORIZONTAL

MONITOR
707
166
855
211
Effort_of_end-users
sum [effort] of end-users
17
1
11

MONITOR
706
215
855
260
Effort of facility companies
sum [effort] of facility_companies
17
1
11

MONITOR
707
265
856
310
Effort of finance and control
[effort] of finance_and_control 1
17
1
11

PLOT
921
169
1128
319
Supplier stock
ticks
Bicycles
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"stock" 1.0 0 -16777216 true "" "plot [stock] of supplier 0"

SLIDER
669
543
880
576
manufacturing_cycle
manufacturing_cycle
1
9
9.0
1
1
months
HORIZONTAL

PLOT
919
13
1128
162
Budgets of facility companies
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
"fc2" 1.0 0 -16777216 true "" "plot [budget] of facility_company 2"
"fc3" 1.0 0 -7500403 true "" "plot [budget] of facility_company 3"
"fc4" 1.0 0 -2674135 true "" "plot [budget] of facility_company 4"
"fc5" 1.0 0 -955883 true "" "plot [budget] of facility_company 5"
"fc6" 1.0 0 -6459832 true "" "plot [budget] of facility_company 6"
"fc7" 1.0 0 -1184463 true "" "plot [budget] of facility_company 7"
"fc8" 1.0 0 -10899396 true "" "plot [budget] of facility_company 8"

SLIDER
669
580
880
613
production_rate
production_rate
1
20
20.0
1
1
bikes per day
HORIZONTAL

MONITOR
708
414
841
459
Average_supply_time
sum list_order_waiting_time / length list_order_waiting_time
2
1
11

MONITOR
708
364
785
409
total bikes
count bicycles
17
1
11

SLIDER
669
617
880
650
max_supplier_stock
max_supplier_stock
50
2000
2000.0
50
1
bicycles
HORIZONTAL

SLIDER
239
582
448
615
initial_justification
initial_justification
0
100
30.0
5
1
NIL
HORIZONTAL

SLIDER
17
344
225
377
yearly_demand_growth
yearly_demand_growth
0
10
5.0
.5
1
%
HORIZONTAL

SLIDER
17
381
225
414
bicycle_average_lifetime_years
bicycle_average_lifetime_years
0
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
18
543
228
576
order_value_limit_fc
order_value_limit_fc
10000
50000
30000.0
1000
1
euros
HORIZONTAL

MONITOR
794
363
866
408
Year
year
17
1
11

TEXTBOX
377
475
561
500
Process parameters
20
0.0
1

TEXTBOX
77
272
152
292
External parameters
17
0.0
1

TEXTBOX
70
516
220
534
Finance and Control
14
0.0
1

TEXTBOX
320
513
386
531
End-users
14
0.0
1

TEXTBOX
507
513
623
531
Facility companies
14
0.0
1

TEXTBOX
758
515
813
533
Supplier
14
0.0
1

TEXTBOX
242
617
432
643
(Justification is the argumentation behind created orders.)
10
0.0
1

SLIDER
463
543
655
576
order_processing_capacity
order_processing_capacity
1
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
240
544
449
577
initial_amount_of_bicycles
initial_amount_of_bicycles
1
10
4.0
.5
1
scale
HORIZONTAL

SLIDER
463
581
655
614
order_value_limit_facco
order_value_limit_facco
0
20000
5000.0
1000
1
NIL
HORIZONTAL

SLIDER
19
581
225
614
critical_budget_left_share
critical_budget_left_share
0
40
10.0
1
1
%
HORIZONTAL

TEXTBOX
14
57
253
101
Structural/parameter policies
17
0.0
1

SWITCH
16
86
221
119
predictive_replacements
predictive_replacements
1
1
-1000

SWITCH
16
125
220
158
improved_information_provision
improved_information_provision
1
1
-1000

SLIDER
16
418
225
451
ticks_in_year
ticks_in_year
52
365
190.0
1
1
NIL
HORIZONTAL

SLIDER
16
455
224
488
burn-in_period
burn-in_period
0
8
1.0
1
1
years
HORIZONTAL

SLIDER
240
649
446
682
share_demand_malfunctioning
share_demand_malfunctioning
1
50
25.0
1
1
%
HORIZONTAL

SLIDER
17
164
221
197
general_willingness_to_share
general_willingness_to_share
1
3
3.0
1
1
NIL
HORIZONTAL

TEXTBOX
35
203
220
221
1 = low, 2 = medium, 3 = high
11
0.0
1

MONITOR
707
314
819
359
effort of manager
sum [Effort] of managers
17
1
11

PLOT
922
325
1122
475
Demand of end-users
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
"default" 1.0 0 -16777216 true "" "plot sum [demand] of end-users"

SLIDER
16
307
224
340
initial_total_demand
initial_total_demand
1000
10000
6000.0
100
1
NIL
HORIZONTAL

MONITOR
708
462
796
507
Total demand
sum [demand] of end-users
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

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

bicycle
true
0
Circle -1 false false 30 150 90
Circle -1 false false 180 150 90
Line -1 false 75 195 105 135
Line -1 false 105 135 165 195
Line -1 false 225 195 195 135
Line -1 false 75 195 165 195
Line -1 false 165 195 195 135
Line -1 false 105 135 195 135
Line -1 false 105 135 105 120
Line -1 false 90 120 120 120
Line -1 false 195 135 195 105
Line -1 false 195 105 180 105
Circle -1 false false 41 161 67
Circle -1 false false 191 161 67

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

euro
true
0
Rectangle -13840069 true false 30 90 270 210
Polygon -16777216 true false 180 105 135 105 120 120 120 135 105 135 105 150 120 150 120 165 105 165 105 180 120 180 135 195 180 195 180 180 135 180 135 165 180 165 165 150 135 150 135 135 150 120 180 120 180 105 285 255

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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
