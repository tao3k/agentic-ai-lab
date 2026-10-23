(declare (block) (standard-bindings) (extended-bindings))
(begin
  (define agentic-ai-lab/src/policy/cedar-authority::timestamp 1788831890)
  (begin
    (define agentic-ai-lab/src/policy/cedar-authority#policy-kind 'cedar-policy)
    (define agentic-ai-lab/src/policy/cedar-authority#Policy.
      (let ((__obj28791
             (let ()
               (declare (not safe))
               (##structure
                clan/poo/object#object::t
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f))))
        (let ((__tmp28810
               (list (cons 'kind
                           (let ((__tmp28811
                                  (lambda (_%self27663%_)
                                    (let* ((_%object27733%_ _%self27663%_)
                                           (_%object27805%_ _%object27733%_)
                                           (_%object27877%_ _%object27805%_))
                                      'cedar-policy))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28811)))
                     (cons 'schema
                           (let ((__tmp28812
                                  (lambda (_%self27949%_)
                                    (let* ((_%object28017%_ _%self27949%_)
                                           (_%object28088%_ _%object28017%_)
                                           (_%object28159%_ _%object28088%_))
                                      'agentic-ai-lab.cedar-values.v1))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28812)))
                     (cons 'runtime-owner
                           (let ((__tmp28813
                                  (lambda (_%self28230%_)
                                    (let* ((_%object28298%_ _%self28230%_)
                                           (_%object28369%_ _%object28298%_)
                                           (_%object28440%_ _%object28369%_))
                                      'native.cedar-authority))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28813)))
                     (cons 'runtime-executed?
                           (let ((__tmp28814
                                  (lambda (_%self28511%_)
                                    (let* ((_%object28579%_ _%self28511%_)
                                           (_%object28650%_ _%object28579%_)
                                           (_%object28721%_ _%object28650%_))
                                      '#f))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28814)))))
              (__tmp28809 (list)))
          (declare (not safe))
          (clan/poo/object#object:::init!__%
           '#f
           '()
           __tmp28810
           __tmp28809
           __obj28791))
        __obj28791))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-policy?
      (lambda (_%value27656%_)
        (if (let ()
              (declare (not safe))
              (##structure-instance-of?
               _%value27656%_
               'clan/poo/object#object::t))
            (let ((__tmp28816 (lambda (_%_failure27659%_) '#f))
                  (__tmp28815
                   (lambda ()
                     (eq? (let ()
                            (declare (not safe))
                            (clan/poo/object#.ref _%value27656%_ 'kind))
                          agentic-ai-lab/src/policy/cedar-authority#policy-kind))))
              (declare (not safe))
              (__with-catch __tmp28816 __tmp28815))
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#schema-kind 'cedar-schema)
    (define agentic-ai-lab/src/policy/cedar-authority#Schema.
      (let ((__obj28792
             (let ()
               (declare (not safe))
               (##structure
                clan/poo/object#object::t
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f))))
        (let ((__tmp28818
               (list (cons 'kind
                           (let ((__tmp28819
                                  (lambda (_%self26527%_)
                                    (let* ((_%object26597%_ _%self26527%_)
                                           (_%object26669%_ _%object26597%_)
                                           (_%object26741%_ _%object26669%_))
                                      'cedar-schema))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28819)))
                     (cons 'schema
                           (let ((__tmp28820
                                  (lambda (_%self26813%_)
                                    (let* ((_%object26881%_ _%self26813%_)
                                           (_%object26952%_ _%object26881%_)
                                           (_%object27023%_ _%object26952%_))
                                      'agentic-ai-lab.cedar-values.v1))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28820)))
                     (cons 'runtime-owner
                           (let ((__tmp28821
                                  (lambda (_%self27094%_)
                                    (let* ((_%object27162%_ _%self27094%_)
                                           (_%object27233%_ _%object27162%_)
                                           (_%object27304%_ _%object27233%_))
                                      'native.cedar-authority))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28821)))
                     (cons 'runtime-executed?
                           (let ((__tmp28822
                                  (lambda (_%self27375%_)
                                    (let* ((_%object27443%_ _%self27375%_)
                                           (_%object27514%_ _%object27443%_)
                                           (_%object27585%_ _%object27514%_))
                                      '#f))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28822)))))
              (__tmp28817 (list)))
          (declare (not safe))
          (clan/poo/object#object:::init!__%
           '#f
           '()
           __tmp28818
           __tmp28817
           __obj28792))
        __obj28792))
    (define agentic-ai-lab/src/policy/cedar-authority#cedar-schema?
      (lambda (_%value26520%_)
        (if (let ()
              (declare (not safe))
              (##structure-instance-of?
               _%value26520%_
               'clan/poo/object#object::t))
            (let ((__tmp28824 (lambda (_%_failure26523%_) '#f))
                  (__tmp28823
                   (lambda ()
                     (eq? (let ()
                            (declare (not safe))
                            (clan/poo/object#.ref _%value26520%_ 'kind))
                          agentic-ai-lab/src/policy/cedar-authority#schema-kind))))
              (declare (not safe))
              (__with-catch __tmp28824 __tmp28823))
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#entities-kind 'cedar-entities)
    (define agentic-ai-lab/src/policy/cedar-authority#Entities.
      (let ((__obj28793
             (let ()
               (declare (not safe))
               (##structure
                clan/poo/object#object::t
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f))))
        (let ((__tmp28826
               (list (cons 'kind
                           (let ((__tmp28827
                                  (lambda (_%self25391%_)
                                    (let* ((_%object25461%_ _%self25391%_)
                                           (_%object25533%_ _%object25461%_)
                                           (_%object25605%_ _%object25533%_))
                                      'cedar-entities))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28827)))
                     (cons 'schema
                           (let ((__tmp28828
                                  (lambda (_%self25677%_)
                                    (let* ((_%object25745%_ _%self25677%_)
                                           (_%object25816%_ _%object25745%_)
                                           (_%object25887%_ _%object25816%_))
                                      'agentic-ai-lab.cedar-values.v1))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28828)))
                     (cons 'runtime-owner
                           (let ((__tmp28829
                                  (lambda (_%self25958%_)
                                    (let* ((_%object26026%_ _%self25958%_)
                                           (_%object26097%_ _%object26026%_)
                                           (_%object26168%_ _%object26097%_))
                                      'native.cedar-authority))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28829)))
                     (cons 'runtime-executed?
                           (let ((__tmp28830
                                  (lambda (_%self26239%_)
                                    (let* ((_%object26307%_ _%self26239%_)
                                           (_%object26378%_ _%object26307%_)
                                           (_%object26449%_ _%object26378%_))
                                      '#f))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28830)))))
              (__tmp28825 (list)))
          (declare (not safe))
          (clan/poo/object#object:::init!__%
           '#f
           '()
           __tmp28826
           __tmp28825
           __obj28793))
        __obj28793))
    (define agentic-ai-lab/src/policy/cedar-authority#cedar-entities?
      (lambda (_%value25384%_)
        (if (let ()
              (declare (not safe))
              (##structure-instance-of?
               _%value25384%_
               'clan/poo/object#object::t))
            (let ((__tmp28832 (lambda (_%_failure25387%_) '#f))
                  (__tmp28831
                   (lambda ()
                     (eq? (let ()
                            (declare (not safe))
                            (clan/poo/object#.ref _%value25384%_ 'kind))
                          agentic-ai-lab/src/policy/cedar-authority#entities-kind))))
              (declare (not safe))
              (__with-catch __tmp28832 __tmp28831))
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#proof-kind
      'cedar-proof-binding)
    (define agentic-ai-lab/src/policy/cedar-authority#ProofBinding.
      (let ((__obj28794
             (let ()
               (declare (not safe))
               (##structure
                clan/poo/object#object::t
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f))))
        (let ((__tmp28834
               (list (cons 'kind
                           (let ((__tmp28835
                                  (lambda (_%self24255%_)
                                    (let* ((_%object24325%_ _%self24255%_)
                                           (_%object24397%_ _%object24325%_)
                                           (_%object24469%_ _%object24397%_))
                                      'cedar-proof-binding))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28835)))
                     (cons 'schema
                           (let ((__tmp28836
                                  (lambda (_%self24541%_)
                                    (let* ((_%object24609%_ _%self24541%_)
                                           (_%object24680%_ _%object24609%_)
                                           (_%object24751%_ _%object24680%_))
                                      'agentic-ai-lab.cedar-values.v1))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28836)))
                     (cons 'runtime-owner
                           (let ((__tmp28837
                                  (lambda (_%self24822%_)
                                    (let* ((_%object24890%_ _%self24822%_)
                                           (_%object24961%_ _%object24890%_)
                                           (_%object25032%_ _%object24961%_))
                                      'native.cedar-authority))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28837)))
                     (cons 'runtime-executed?
                           (let ((__tmp28838
                                  (lambda (_%self25103%_)
                                    (let* ((_%object25171%_ _%self25103%_)
                                           (_%object25242%_ _%object25171%_)
                                           (_%object25313%_ _%object25242%_))
                                      '#f))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28838)))))
              (__tmp28833 (list)))
          (declare (not safe))
          (clan/poo/object#object:::init!__%
           '#f
           '()
           __tmp28834
           __tmp28833
           __obj28794))
        __obj28794))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-proof-binding?
      (lambda (_%value24248%_)
        (if (let ()
              (declare (not safe))
              (##structure-instance-of?
               _%value24248%_
               'clan/poo/object#object::t))
            (let ((__tmp28840 (lambda (_%_failure24251%_) '#f))
                  (__tmp28839
                   (lambda ()
                     (eq? (let ()
                            (declare (not safe))
                            (clan/poo/object#.ref _%value24248%_ 'kind))
                          agentic-ai-lab/src/policy/cedar-authority#proof-kind))))
              (declare (not safe))
              (__with-catch __tmp28840 __tmp28839))
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#context-kind
      'cedar-authority-context)
    (define agentic-ai-lab/src/policy/cedar-authority#AuthorityContext.
      (let ((__obj28795
             (let ()
               (declare (not safe))
               (##structure
                clan/poo/object#object::t
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f))))
        (let ((__tmp28842
               (list (cons 'kind
                           (let ((__tmp28843
                                  (lambda (_%self23119%_)
                                    (let* ((_%object23189%_ _%self23119%_)
                                           (_%object23261%_ _%object23189%_)
                                           (_%object23333%_ _%object23261%_))
                                      'cedar-authority-context))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28843)))
                     (cons 'schema
                           (let ((__tmp28844
                                  (lambda (_%self23405%_)
                                    (let* ((_%object23473%_ _%self23405%_)
                                           (_%object23544%_ _%object23473%_)
                                           (_%object23615%_ _%object23544%_))
                                      'agentic-ai-lab.cedar-values.v1))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28844)))
                     (cons 'runtime-owner
                           (let ((__tmp28845
                                  (lambda (_%self23686%_)
                                    (let* ((_%object23754%_ _%self23686%_)
                                           (_%object23825%_ _%object23754%_)
                                           (_%object23896%_ _%object23825%_))
                                      'native.cedar-authority))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28845)))
                     (cons 'runtime-executed?
                           (let ((__tmp28846
                                  (lambda (_%self23967%_)
                                    (let* ((_%object24035%_ _%self23967%_)
                                           (_%object24106%_ _%object24035%_)
                                           (_%object24177%_ _%object24106%_))
                                      '#f))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28846)))))
              (__tmp28841 (list)))
          (declare (not safe))
          (clan/poo/object#object:::init!__%
           '#f
           '()
           __tmp28842
           __tmp28841
           __obj28795))
        __obj28795))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authority-context?
      (lambda (_%value23112%_)
        (if (let ()
              (declare (not safe))
              (##structure-instance-of?
               _%value23112%_
               'clan/poo/object#object::t))
            (let ((__tmp28848 (lambda (_%_failure23115%_) '#f))
                  (__tmp28847
                   (lambda ()
                     (eq? (let ()
                            (declare (not safe))
                            (clan/poo/object#.ref _%value23112%_ 'kind))
                          agentic-ai-lab/src/policy/cedar-authority#context-kind))))
              (declare (not safe))
              (__with-catch __tmp28848 __tmp28847))
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#capability-kind
      'cedar-runtime-capability)
    (define agentic-ai-lab/src/policy/cedar-authority#Capability.
      (let ((__obj28796
             (let ()
               (declare (not safe))
               (##structure
                clan/poo/object#object::t
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f))))
        (let ((__tmp28850
               (list (cons 'kind
                           (let ((__tmp28851
                                  (lambda (_%self21983%_)
                                    (let* ((_%object22053%_ _%self21983%_)
                                           (_%object22125%_ _%object22053%_)
                                           (_%object22197%_ _%object22125%_))
                                      'cedar-runtime-capability))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28851)))
                     (cons 'schema
                           (let ((__tmp28852
                                  (lambda (_%self22269%_)
                                    (let* ((_%object22337%_ _%self22269%_)
                                           (_%object22408%_ _%object22337%_)
                                           (_%object22479%_ _%object22408%_))
                                      'agentic-ai-lab.cedar-values.v1))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28852)))
                     (cons 'runtime-owner
                           (let ((__tmp28853
                                  (lambda (_%self22550%_)
                                    (let* ((_%object22618%_ _%self22550%_)
                                           (_%object22689%_ _%object22618%_)
                                           (_%object22760%_ _%object22689%_))
                                      'native.cedar-authority))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28853)))
                     (cons 'runtime-executed?
                           (let ((__tmp28854
                                  (lambda (_%self22831%_)
                                    (let* ((_%object22899%_ _%self22831%_)
                                           (_%object22970%_ _%object22899%_)
                                           (_%object23041%_ _%object22970%_))
                                      '#f))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28854)))))
              (__tmp28849 (list)))
          (declare (not safe))
          (clan/poo/object#object:::init!__%
           '#f
           '()
           __tmp28850
           __tmp28849
           __obj28796))
        __obj28796))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-runtime-capability?
      (lambda (_%value21976%_)
        (if (let ()
              (declare (not safe))
              (##structure-instance-of?
               _%value21976%_
               'clan/poo/object#object::t))
            (let ((__tmp28856 (lambda (_%_failure21979%_) '#f))
                  (__tmp28855
                   (lambda ()
                     (eq? (let ()
                            (declare (not safe))
                            (clan/poo/object#.ref _%value21976%_ 'kind))
                          agentic-ai-lab/src/policy/cedar-authority#capability-kind))))
              (declare (not safe))
              (__with-catch __tmp28856 __tmp28855))
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#snapshot-kind
      'cedar-authority-snapshot)
    (define agentic-ai-lab/src/policy/cedar-authority#Snapshot.
      (let ((__obj28797
             (let ()
               (declare (not safe))
               (##structure
                clan/poo/object#object::t
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f))))
        (let ((__tmp28858
               (list (cons 'kind
                           (let ((__tmp28859
                                  (lambda (_%self20847%_)
                                    (let* ((_%object20917%_ _%self20847%_)
                                           (_%object20989%_ _%object20917%_)
                                           (_%object21061%_ _%object20989%_))
                                      'cedar-authority-snapshot))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28859)))
                     (cons 'schema
                           (let ((__tmp28860
                                  (lambda (_%self21133%_)
                                    (let* ((_%object21201%_ _%self21133%_)
                                           (_%object21272%_ _%object21201%_)
                                           (_%object21343%_ _%object21272%_))
                                      'agentic-ai-lab.cedar-values.v1))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28860)))
                     (cons 'runtime-owner
                           (let ((__tmp28861
                                  (lambda (_%self21414%_)
                                    (let* ((_%object21482%_ _%self21414%_)
                                           (_%object21553%_ _%object21482%_)
                                           (_%object21624%_ _%object21553%_))
                                      'native.cedar-authority))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28861)))
                     (cons 'runtime-executed?
                           (let ((__tmp28862
                                  (lambda (_%self21695%_)
                                    (let* ((_%object21763%_ _%self21695%_)
                                           (_%object21834%_ _%object21763%_)
                                           (_%object21905%_ _%object21834%_))
                                      '#f))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28862)))))
              (__tmp28857 (list)))
          (declare (not safe))
          (clan/poo/object#object:::init!__%
           '#f
           '()
           __tmp28858
           __tmp28857
           __obj28797))
        __obj28797))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authority-snapshot?
      (lambda (_%value20840%_)
        (if (let ()
              (declare (not safe))
              (##structure-instance-of?
               _%value20840%_
               'clan/poo/object#object::t))
            (let ((__tmp28864 (lambda (_%_failure20843%_) '#f))
                  (__tmp28863
                   (lambda ()
                     (eq? (let ()
                            (declare (not safe))
                            (clan/poo/object#.ref _%value20840%_ 'kind))
                          agentic-ai-lab/src/policy/cedar-authority#snapshot-kind))))
              (declare (not safe))
              (__with-catch __tmp28864 __tmp28863))
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#handoff-kind
      'cedar-runtime-handoff)
    (define agentic-ai-lab/src/policy/cedar-authority#Handoff.
      (let ((__obj28798
             (let ()
               (declare (not safe))
               (##structure
                clan/poo/object#object::t
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f))))
        (let ((__tmp28866
               (list (cons 'kind
                           (let ((__tmp28867
                                  (lambda (_%self19711%_)
                                    (let* ((_%object19781%_ _%self19711%_)
                                           (_%object19853%_ _%object19781%_)
                                           (_%object19925%_ _%object19853%_))
                                      'cedar-runtime-handoff))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28867)))
                     (cons 'schema
                           (let ((__tmp28868
                                  (lambda (_%self19997%_)
                                    (let* ((_%object20065%_ _%self19997%_)
                                           (_%object20136%_ _%object20065%_)
                                           (_%object20207%_ _%object20136%_))
                                      'agentic-ai-lab.cedar-values.v1))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28868)))
                     (cons 'runtime-owner
                           (let ((__tmp28869
                                  (lambda (_%self20278%_)
                                    (let* ((_%object20346%_ _%self20278%_)
                                           (_%object20417%_ _%object20346%_)
                                           (_%object20488%_ _%object20417%_))
                                      'native.cedar-authority))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28869)))
                     (cons 'runtime-executed?
                           (let ((__tmp28870
                                  (lambda (_%self20559%_)
                                    (let* ((_%object20627%_ _%self20559%_)
                                           (_%object20698%_ _%object20627%_)
                                           (_%object20769%_ _%object20698%_))
                                      '#f))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28870)))))
              (__tmp28865 (list)))
          (declare (not safe))
          (clan/poo/object#object:::init!__%
           '#f
           '()
           __tmp28866
           __tmp28865
           __obj28798))
        __obj28798))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-runtime-handoff?
      (lambda (_%value19704%_)
        (if (let ()
              (declare (not safe))
              (##structure-instance-of?
               _%value19704%_
               'clan/poo/object#object::t))
            (let ((__tmp28872 (lambda (_%_failure19707%_) '#f))
                  (__tmp28871
                   (lambda ()
                     (eq? (let ()
                            (declare (not safe))
                            (clan/poo/object#.ref _%value19704%_ 'kind))
                          agentic-ai-lab/src/policy/cedar-authority#handoff-kind))))
              (declare (not safe))
              (__with-catch __tmp28872 __tmp28871))
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#request-kind
      'cedar-authorization-request)
    (define agentic-ai-lab/src/policy/cedar-authority#Request.
      (let ((__obj28799
             (let ()
               (declare (not safe))
               (##structure
                clan/poo/object#object::t
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f
                '#f))))
        (let ((__tmp28874
               (list (cons 'kind
                           (let ((__tmp28875
                                  (lambda (_%self18575%_)
                                    (let* ((_%object18645%_ _%self18575%_)
                                           (_%object18717%_ _%object18645%_)
                                           (_%object18789%_ _%object18717%_))
                                      'cedar-authorization-request))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28875)))
                     (cons 'schema
                           (let ((__tmp28876
                                  (lambda (_%self18861%_)
                                    (let* ((_%object18929%_ _%self18861%_)
                                           (_%object19000%_ _%object18929%_)
                                           (_%object19071%_ _%object19000%_))
                                      'agentic-ai-lab.cedar-values.v1))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28876)))
                     (cons 'runtime-owner
                           (let ((__tmp28877
                                  (lambda (_%self19142%_)
                                    (let* ((_%object19210%_ _%self19142%_)
                                           (_%object19281%_ _%object19210%_)
                                           (_%object19352%_ _%object19281%_))
                                      'native.cedar-authority))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28877)))
                     (cons 'runtime-executed?
                           (let ((__tmp28878
                                  (lambda (_%self19423%_)
                                    (let* ((_%object19491%_ _%self19423%_)
                                           (_%object19562%_ _%object19491%_)
                                           (_%object19633%_ _%object19562%_))
                                      '#f))))
                             (declare (not safe))
                             (##structure
                              clan/poo/object#$self-slot-spec::t
                              __tmp28878)))))
              (__tmp28873 (list)))
          (declare (not safe))
          (clan/poo/object#object:::init!__%
           '#f
           '()
           __tmp28874
           __tmp28873
           __obj28799))
        __obj28799))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authorization-request?
      (lambda (_%value18568%_)
        (if (let ()
              (declare (not safe))
              (##structure-instance-of?
               _%value18568%_
               'clan/poo/object#object::t))
            (let ((__tmp28880 (lambda (_%_failure18571%_) '#f))
                  (__tmp28879
                   (lambda ()
                     (eq? (let ()
                            (declare (not safe))
                            (clan/poo/object#.ref _%value18568%_ 'kind))
                          agentic-ai-lab/src/policy/cedar-authority#request-kind))))
              (declare (not safe))
              (__with-catch __tmp28880 __tmp28879))
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#require-value
      (lambda (_%message18564%_ _%accepted?18565%_ _%value18566%_)
        (if _%accepted?18565%_
            '#!void
            (let ()
              (declare (not safe))
              (error _%message18564%_ _%value18566%_)))))
    (define agentic-ai-lab/src/policy/cedar-authority#text?
      (lambda (_%value18562%_)
        (if (string? _%value18562%_)
            (> (let () (declare (not safe)) (##string-length _%value18562%_))
               '0)
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#natural?
      (lambda (_%value18560%_)
        (if (exact-integer? _%value18560%_)
            (<= '0 _%value18560%_ '9223372036854775807)
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#positive?
      (lambda (_%value18558%_)
        (if (agentic-ai-lab/src/policy/cedar-authority#natural? _%value18558%_)
            (> _%value18558%_ '0)
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#every?
      (lambda (_%predicate18548%_ _%values18549%_)
        (if (list? _%values18549%_)
            (let _%loop18551%_ ((_%rest18553%_ _%values18549%_))
              (let ((_%$e18555%_ (null? _%rest18553%_)))
                (if _%$e18555%_
                    _%$e18555%_
                    (if (_%predicate18548%_ (car _%rest18553%_))
                        (_%loop18551%_ (cdr _%rest18553%_))
                        '#f))))
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#digest?
      (lambda (_%value18534%_)
        (if (string? _%value18534%_)
            (if (= (let ()
                     (declare (not safe))
                     (##string-length _%value18534%_))
                   '71)
                (if (let ((__tmp28881 (substring _%value18534%_ '0 '7)))
                      (declare (not safe))
                      (##string=? __tmp28881 '"sha256:"))
                    (let _%loop18536%_ ((_%index18538%_ '7))
                      (let ((_%$e18540%_ (= _%index18538%_ '71)))
                        (if _%$e18540%_
                            _%$e18540%_
                            (let ((_%character18543%_
                                   (string-ref _%value18534%_ _%index18538%_)))
                              (if (or (let ()
                                        (declare (not safe))
                                        (##char<=?
                                         '#\0
                                         _%character18543%_
                                         '#\9))
                                      (let ()
                                        (declare (not safe))
                                        (##char<=?
                                         '#\a
                                         _%character18543%_
                                         '#\f)))
                                  (_%loop18536%_ (+ _%index18538%_ '1))
                                  '#f)))))
                    '#f)
                '#f)
            '#f)))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-policy
      (lambda (_%identity-value18251%_ _%source-value18252%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"Cedar policy identity/source must be nonempty text"
         (if (agentic-ai-lab/src/policy/cedar-authority#text?
              _%identity-value18251%_)
             (agentic-ai-lab/src/policy/cedar-authority#text? _%source-value18252%_)
             '#f)
         _%identity-value18251%_)
        (let ((__obj28800
               (let ()
                 (declare (not safe))
                 (##structure
                  clan/poo/object#object::t
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f))))
          (let ((__tmp28883
                 (list (cons 'identity
                             (let ((__tmp28884
                                    (lambda (_%@18254%_)
                                      (let ((_%object18324%_ _%@18254%_))
                                        _%identity-value18251%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28884)))
                       (cons 'source
                             (let ((__tmp28885
                                    (lambda (_%@18395%_)
                                      (let ((_%object18463%_ _%@18395%_))
                                        _%source-value18252%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28885)))))
                (__tmp28882 (list)))
            (declare (not safe))
            (clan/poo/object#object:::init!__%
             '#f
             agentic-ai-lab/src/policy/cedar-authority#Policy.
             __tmp28883
             __tmp28882
             __obj28800))
          __obj28800)))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-schema
      (lambda (_%document-value18179%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"Cedar schema must be a JSON document"
         (agentic-ai-lab/src/policy/cedar-authority#text? _%document-value18179%_)
         _%document-value18179%_)
        (let ((__obj28801
               (let ()
                 (declare (not safe))
                 (##structure
                  clan/poo/object#object::t
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f))))
          (let ((__tmp28887
                 (list (cons 'document
                             (let ((__tmp28888
                                    (lambda (_%@18181%_)
                                      _%document-value18179%_)))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28888)))))
                (__tmp28886 (list)))
            (declare (not safe))
            (clan/poo/object#object:::init!__%
             '#f
             agentic-ai-lab/src/policy/cedar-authority#Schema.
             __tmp28887
             __tmp28886
             __obj28801))
          __obj28801)))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-entities
      (lambda (_%document-value18107%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"Cedar entities must be a JSON document"
         (agentic-ai-lab/src/policy/cedar-authority#text? _%document-value18107%_)
         _%document-value18107%_)
        (let ((__obj28802
               (let ()
                 (declare (not safe))
                 (##structure
                  clan/poo/object#object::t
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f))))
          (let ((__tmp28890
                 (list (cons 'document
                             (let ((__tmp28891
                                    (lambda (_%@18109%_)
                                      _%document-value18107%_)))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28891)))))
                (__tmp28889 (list)))
            (declare (not safe))
            (clan/poo/object#object:::init!__%
             '#f
             agentic-ai-lab/src/policy/cedar-authority#Entities.
             __tmp28890
             __tmp28889
             __obj28802))
          __obj28802)))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-proof-binding
      (lambda (_%composition-value15560%_
               _%origin-value15561%_
               _%profile-value15562%_
               _%independent-value15563%_
               _%capability-value15564%_
               _%names-value15565%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"composition identity must be text"
         (agentic-ai-lab/src/policy/cedar-authority#text? _%composition-value15560%_)
         _%composition-value15560%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"proof binding requires canonical content identities"
         (agentic-ai-lab/src/policy/cedar-authority#every?
          agentic-ai-lab/src/policy/cedar-authority#digest?
          (list _%origin-value15561%_
                _%profile-value15562%_
                _%independent-value15563%_
                _%capability-value15564%_))
         _%composition-value15560%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"proof binding requires named certifications"
         (if (pair? _%names-value15565%_)
             (agentic-ai-lab/src/policy/cedar-authority#every?
              agentic-ai-lab/src/policy/cedar-authority#text?
              _%names-value15565%_)
             '#f)
         _%names-value15565%_)
        (let ((__obj28803
               (let ()
                 (declare (not safe))
                 (##structure
                  clan/poo/object#object::t
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f))))
          (let ((__tmp28893
                 (list (cons 'composition
                             (let ((__tmp28894
                                    (lambda (_%@15567%_)
                                      (let* ((_%object15637%_ _%@15567%_)
                                             (_%object15708%_ _%object15637%_)
                                             (_%object15779%_ _%object15708%_)
                                             (_%object15850%_ _%object15779%_)
                                             (_%object15921%_ _%object15850%_))
                                        _%composition-value15560%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28894)))
                       (cons 'profile-origin
                             (let ((__tmp28895
                                    (lambda (_%@15992%_)
                                      (let* ((_%object16060%_ _%@15992%_)
                                             (_%object16131%_ _%object16060%_)
                                             (_%object16202%_ _%object16131%_)
                                             (_%object16273%_ _%object16202%_)
                                             (_%object16344%_ _%object16273%_))
                                        _%origin-value15561%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28895)))
                       (cons 'profile-bundle
                             (let ((__tmp28896
                                    (lambda (_%@16415%_)
                                      (let* ((_%object16483%_ _%@16415%_)
                                             (_%object16554%_ _%object16483%_)
                                             (_%object16625%_ _%object16554%_)
                                             (_%object16696%_ _%object16625%_)
                                             (_%object16767%_ _%object16696%_))
                                        _%profile-value15562%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28896)))
                       (cons 'independent-bundle
                             (let ((__tmp28897
                                    (lambda (_%@16838%_)
                                      (let* ((_%object16906%_ _%@16838%_)
                                             (_%object16977%_ _%object16906%_)
                                             (_%object17048%_ _%object16977%_)
                                             (_%object17119%_ _%object17048%_)
                                             (_%object17190%_ _%object17119%_))
                                        _%independent-value15563%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28897)))
                       (cons 'capability-contract
                             (let ((__tmp28898
                                    (lambda (_%@17261%_)
                                      (let* ((_%object17329%_ _%@17261%_)
                                             (_%object17400%_ _%object17329%_)
                                             (_%object17471%_ _%object17400%_)
                                             (_%object17542%_ _%object17471%_)
                                             (_%object17613%_ _%object17542%_))
                                        _%capability-value15564%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28898)))
                       (cons 'certification-names
                             (let ((__tmp28899
                                    (lambda (_%@17684%_)
                                      (let* ((_%object17752%_ _%@17684%_)
                                             (_%object17823%_ _%object17752%_)
                                             (_%object17894%_ _%object17823%_)
                                             (_%object17965%_ _%object17894%_)
                                             (_%object18036%_ _%object17965%_))
                                        _%names-value15565%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28899)))))
                (__tmp28892 (list)))
            (declare (not safe))
            (clan/poo/object#object:::init!__%
             '#f
             agentic-ai-lab/src/policy/cedar-authority#ProofBinding.
             __tmp28893
             __tmp28892
             __obj28803))
          __obj28803)))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authority-context
      (lambda (_%authority-value12092%_
               _%context-value12093%_
               _%generation-value12094%_
               _%bundle-value12095%_
               _%epoch-value12096%_
               _%policy-value12097%_
               _%revocation-value12098%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"authority and runtime context must be text"
         (if (agentic-ai-lab/src/policy/cedar-authority#text?
              _%authority-value12092%_)
             (agentic-ai-lab/src/policy/cedar-authority#text? _%context-value12093%_)
             '#f)
         _%authority-value12092%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"runtime generation and policy revision must be positive"
         (if (agentic-ai-lab/src/policy/cedar-authority#positive?
              _%generation-value12094%_)
             (agentic-ai-lab/src/policy/cedar-authority#positive?
              _%policy-value12097%_)
             '#f)
         _%generation-value12094%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"bundle/revocation epochs must be natural integers"
         (if (agentic-ai-lab/src/policy/cedar-authority#natural?
              _%epoch-value12096%_)
             (agentic-ai-lab/src/policy/cedar-authority#natural?
              _%revocation-value12098%_)
             '#f)
         _%epoch-value12096%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"runtime bundle must be a content identity"
         (agentic-ai-lab/src/policy/cedar-authority#digest? _%bundle-value12095%_)
         _%bundle-value12095%_)
        (let ((__obj28804
               (let ()
                 (declare (not safe))
                 (##structure
                  clan/poo/object#object::t
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f))))
          (let ((__tmp28901
                 (list (cons 'authority
                             (let ((__tmp28902
                                    (lambda (_%@12100%_)
                                      (let* ((_%object12170%_ _%@12100%_)
                                             (_%object12241%_ _%object12170%_)
                                             (_%object12312%_ _%object12241%_)
                                             (_%object12383%_ _%object12312%_)
                                             (_%object12454%_ _%object12383%_)
                                             (_%object12525%_ _%object12454%_))
                                        _%authority-value12092%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28902)))
                       (cons 'runtime-context
                             (let ((__tmp28903
                                    (lambda (_%@12596%_)
                                      (let* ((_%object12664%_ _%@12596%_)
                                             (_%object12735%_ _%object12664%_)
                                             (_%object12806%_ _%object12735%_)
                                             (_%object12877%_ _%object12806%_)
                                             (_%object12948%_ _%object12877%_)
                                             (_%object13019%_ _%object12948%_))
                                        _%context-value12093%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28903)))
                       (cons 'generation
                             (let ((__tmp28904
                                    (lambda (_%@13090%_)
                                      (let* ((_%object13158%_ _%@13090%_)
                                             (_%object13229%_ _%object13158%_)
                                             (_%object13300%_ _%object13229%_)
                                             (_%object13371%_ _%object13300%_)
                                             (_%object13442%_ _%object13371%_)
                                             (_%object13513%_ _%object13442%_))
                                        _%generation-value12094%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28904)))
                       (cons 'runtime-bundle
                             (let ((__tmp28905
                                    (lambda (_%@13584%_)
                                      (let* ((_%object13652%_ _%@13584%_)
                                             (_%object13723%_ _%object13652%_)
                                             (_%object13794%_ _%object13723%_)
                                             (_%object13865%_ _%object13794%_)
                                             (_%object13936%_ _%object13865%_)
                                             (_%object14007%_ _%object13936%_))
                                        _%bundle-value12095%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28905)))
                       (cons 'bundle-epoch
                             (let ((__tmp28906
                                    (lambda (_%@14078%_)
                                      (let* ((_%object14146%_ _%@14078%_)
                                             (_%object14217%_ _%object14146%_)
                                             (_%object14288%_ _%object14217%_)
                                             (_%object14359%_ _%object14288%_)
                                             (_%object14430%_ _%object14359%_)
                                             (_%object14501%_ _%object14430%_))
                                        _%epoch-value12096%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28906)))
                       (cons 'policy-revision
                             (let ((__tmp28907
                                    (lambda (_%@14572%_)
                                      (let* ((_%object14640%_ _%@14572%_)
                                             (_%object14711%_ _%object14640%_)
                                             (_%object14782%_ _%object14711%_)
                                             (_%object14853%_ _%object14782%_)
                                             (_%object14924%_ _%object14853%_)
                                             (_%object14995%_ _%object14924%_))
                                        _%policy-value12097%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28907)))
                       (cons 'revocation-epoch
                             (let ((__tmp28908
                                    (lambda (_%@15066%_)
                                      (let* ((_%object15134%_ _%@15066%_)
                                             (_%object15205%_ _%object15134%_)
                                             (_%object15276%_ _%object15205%_)
                                             (_%object15347%_ _%object15276%_)
                                             (_%object15418%_ _%object15347%_)
                                             (_%object15489%_ _%object15418%_))
                                        _%revocation-value12098%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28908)))))
                (__tmp28900 (list)))
            (declare (not safe))
            (clan/poo/object#object:::init!__%
             '#f
             agentic-ai-lab/src/policy/cedar-authority#AuthorityContext.
             __tmp28901
             __tmp28900
             __obj28804))
          __obj28804)))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-runtime-capability
      (lambda (_%action-value11809%_ _%event-value11810%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"Cedar action must be text"
         (agentic-ai-lab/src/policy/cedar-authority#text? _%action-value11809%_)
         _%action-value11809%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"runtime event kind must be a positive uint32"
         (if (agentic-ai-lab/src/policy/cedar-authority#positive?
              _%event-value11810%_)
             (<= _%event-value11810%_ '4294967295)
             '#f)
         _%event-value11810%_)
        (let ((__obj28805
               (let ()
                 (declare (not safe))
                 (##structure
                  clan/poo/object#object::t
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f))))
          (let ((__tmp28910
                 (list (cons 'action
                             (let ((__tmp28911
                                    (lambda (_%@11812%_)
                                      (let ((_%object11882%_ _%@11812%_))
                                        _%action-value11809%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28911)))
                       (cons 'event-kind
                             (let ((__tmp28912
                                    (lambda (_%@11953%_)
                                      (let ((_%object12021%_ _%@11953%_))
                                        _%event-value11810%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28912)))))
                (__tmp28909 (list)))
            (declare (not safe))
            (clan/poo/object#object:::init!__%
             '#f
             agentic-ai-lab/src/policy/cedar-authority#Capability.
             __tmp28910
             __tmp28909
             __obj28805))
          __obj28805)))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authority-snapshot
      (lambda (_%context-value9262%_
               _%proof-value9263%_
               _%policy-values9264%_
               _%schema-value9265%_
               _%entities-value9266%_
               _%capability-values9267%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"authority snapshot requires AuthorityContext"
         (agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authority-context?
          _%context-value9262%_)
         _%context-value9262%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"authority snapshot requires ProofBinding"
         (agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-proof-binding?
          _%proof-value9263%_)
         _%proof-value9263%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"authority snapshot requires POO Cedar policies"
         (agentic-ai-lab/src/policy/cedar-authority#every?
          agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-policy?
          _%policy-values9264%_)
         _%policy-values9264%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"authority snapshot requires Cedar schema/entities documents"
         (if (agentic-ai-lab/src/policy/cedar-authority#cedar-schema?
              _%schema-value9265%_)
             (agentic-ai-lab/src/policy/cedar-authority#cedar-entities?
              _%entities-value9266%_)
             '#f)
         _%schema-value9265%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"authority snapshot requires POO runtime capabilities"
         (if (pair? _%capability-values9267%_)
             (agentic-ai-lab/src/policy/cedar-authority#every?
              agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-runtime-capability?
              _%capability-values9267%_)
             '#f)
         _%capability-values9267%_)
        (let ((__obj28806
               (let ()
                 (declare (not safe))
                 (##structure
                  clan/poo/object#object::t
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f))))
          (let ((__tmp28914
                 (list (cons 'context
                             (let ((__tmp28915
                                    (lambda (_%@9269%_)
                                      (let* ((_%object9339%_ _%@9269%_)
                                             (_%object9410%_ _%object9339%_)
                                             (_%object9481%_ _%object9410%_)
                                             (_%object9552%_ _%object9481%_)
                                             (_%object9623%_ _%object9552%_))
                                        _%context-value9262%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28915)))
                       (cons 'proof-binding
                             (let ((__tmp28916
                                    (lambda (_%@9694%_)
                                      (let* ((_%object9762%_ _%@9694%_)
                                             (_%object9833%_ _%object9762%_)
                                             (_%object9904%_ _%object9833%_)
                                             (_%object9975%_ _%object9904%_)
                                             (_%object10046%_ _%object9975%_))
                                        _%proof-value9263%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28916)))
                       (cons 'policies
                             (let ((__tmp28917
                                    (lambda (_%@10117%_)
                                      (let* ((_%object10185%_ _%@10117%_)
                                             (_%object10256%_ _%object10185%_)
                                             (_%object10327%_ _%object10256%_)
                                             (_%object10398%_ _%object10327%_)
                                             (_%object10469%_ _%object10398%_))
                                        _%policy-values9264%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28917)))
                       (cons 'cedar-schema
                             (let ((__tmp28918
                                    (lambda (_%@10540%_)
                                      (let* ((_%object10608%_ _%@10540%_)
                                             (_%object10679%_ _%object10608%_)
                                             (_%object10750%_ _%object10679%_)
                                             (_%object10821%_ _%object10750%_)
                                             (_%object10892%_ _%object10821%_))
                                        _%schema-value9265%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28918)))
                       (cons 'entities
                             (let ((__tmp28919
                                    (lambda (_%@10963%_)
                                      (let* ((_%object11031%_ _%@10963%_)
                                             (_%object11102%_ _%object11031%_)
                                             (_%object11173%_ _%object11102%_)
                                             (_%object11244%_ _%object11173%_)
                                             (_%object11315%_ _%object11244%_))
                                        _%entities-value9266%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28919)))
                       (cons 'capabilities
                             (let ((__tmp28920
                                    (lambda (_%@11386%_)
                                      (let* ((_%object11454%_ _%@11386%_)
                                             (_%object11525%_ _%object11454%_)
                                             (_%object11596%_ _%object11525%_)
                                             (_%object11667%_ _%object11596%_)
                                             (_%object11738%_ _%object11667%_))
                                        _%capability-values9267%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28920)))))
                (__tmp28913 (list)))
            (declare (not safe))
            (clan/poo/object#object:::init!__%
             '#f
             agentic-ai-lab/src/policy/cedar-authority#Snapshot.
             __tmp28914
             __tmp28913
             __obj28806))
          __obj28806)))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-runtime-handoff
      (lambda (_%sequence-value6715%_
               _%payload-value6716%_
               _%semantic-value6717%_
               _%before-value6718%_
               _%after-value6719%_
               _%observation-value6720%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"handoff sequence must be positive"
         (agentic-ai-lab/src/policy/cedar-authority#positive? _%sequence-value6715%_)
         _%sequence-value6715%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"handoff payload must be at most 64 KiB of bytes"
         (if (u8vector? _%payload-value6716%_)
             (<= (let ()
                   (declare (not safe))
                   (##u8vector-length _%payload-value6716%_))
                 '65536)
             '#f)
         _%sequence-value6715%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"handoff roots must be canonical content identities"
         (agentic-ai-lab/src/policy/cedar-authority#every?
          agentic-ai-lab/src/policy/cedar-authority#digest?
          (list _%semantic-value6717%_
                _%before-value6718%_
                _%after-value6719%_
                _%observation-value6720%_))
         _%sequence-value6715%_)
        (let ((__obj28807
               (let ()
                 (declare (not safe))
                 (##structure
                  clan/poo/object#object::t
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f))))
          (let ((__tmp28922
                 (list (cons 'sequence
                             (let ((__tmp28923
                                    (lambda (_%@6722%_)
                                      (let* ((_%object6792%_ _%@6722%_)
                                             (_%object6863%_ _%object6792%_)
                                             (_%object6934%_ _%object6863%_)
                                             (_%object7005%_ _%object6934%_)
                                             (_%object7076%_ _%object7005%_))
                                        _%sequence-value6715%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28923)))
                       (cons 'payload-hex
                             (let ((__tmp28924
                                    (lambda (_%@7147%_)
                                      (let* ((_%object7215%_ _%@7147%_)
                                             (_%object7286%_ _%object7215%_)
                                             (_%object7357%_ _%object7286%_)
                                             (_%object7428%_ _%object7357%_)
                                             (_%object7499%_ _%object7428%_))
                                        (declare (not safe))
                                        (std/text/hex#hex-encode__0
                                         _%payload-value6716%_)))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28924)))
                       (cons 'semantic-root
                             (let ((__tmp28925
                                    (lambda (_%@7570%_)
                                      (let* ((_%object7638%_ _%@7570%_)
                                             (_%object7709%_ _%object7638%_)
                                             (_%object7780%_ _%object7709%_)
                                             (_%object7851%_ _%object7780%_)
                                             (_%object7922%_ _%object7851%_))
                                        _%semantic-value6717%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28925)))
                       (cons 'before-execution-root
                             (let ((__tmp28926
                                    (lambda (_%@7993%_)
                                      (let* ((_%object8061%_ _%@7993%_)
                                             (_%object8132%_ _%object8061%_)
                                             (_%object8203%_ _%object8132%_)
                                             (_%object8274%_ _%object8203%_)
                                             (_%object8345%_ _%object8274%_))
                                        _%before-value6718%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28926)))
                       (cons 'after-execution-root
                             (let ((__tmp28927
                                    (lambda (_%@8416%_)
                                      (let* ((_%object8484%_ _%@8416%_)
                                             (_%object8555%_ _%object8484%_)
                                             (_%object8626%_ _%object8555%_)
                                             (_%object8697%_ _%object8626%_)
                                             (_%object8768%_ _%object8697%_))
                                        _%after-value6719%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28927)))
                       (cons 'observation-digest
                             (let ((__tmp28928
                                    (lambda (_%@8839%_)
                                      (let* ((_%object8907%_ _%@8839%_)
                                             (_%object8978%_ _%object8907%_)
                                             (_%object9049%_ _%object8978%_)
                                             (_%object9120%_ _%object9049%_)
                                             (_%object9191%_ _%object9120%_))
                                        _%observation-value6720%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28928)))))
                (__tmp28921 (list)))
            (declare (not safe))
            (clan/poo/object#object:::init!__%
             '#f
             agentic-ai-lab/src/policy/cedar-authority#Handoff.
             __tmp28922
             __tmp28921
             __obj28807))
          __obj28807)))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authorization-request
      (lambda (_%principal-value4168%_
               _%action-value4169%_
               _%resource-value4170%_
               _%context-value4171%_
               _%intent-value4172%_
               _%handoff-value4173%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"Cedar subject identifiers must be text"
         (agentic-ai-lab/src/policy/cedar-authority#every?
          agentic-ai-lab/src/policy/cedar-authority#text?
          (list _%principal-value4168%_
                _%action-value4169%_
                _%resource-value4170%_))
         _%principal-value4168%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"Cedar context must be a POO object"
         (let ()
           (declare (not safe))
           (##structure-instance-of?
            _%context-value4171%_
            'clan/poo/object#object::t))
         _%context-value4171%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"intent must be a canonical content identity"
         (agentic-ai-lab/src/policy/cedar-authority#digest? _%intent-value4172%_)
         _%intent-value4172%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"authorization requires a runtime handoff value"
         (agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-runtime-handoff?
          _%handoff-value4173%_)
         _%handoff-value4173%_)
        (let ((__obj28808
               (let ()
                 (declare (not safe))
                 (##structure
                  clan/poo/object#object::t
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f
                  '#f))))
          (let ((__tmp28930
                 (list (cons 'principal
                             (let ((__tmp28931
                                    (lambda (_%@4175%_)
                                      (let* ((_%object4245%_ _%@4175%_)
                                             (_%object4316%_ _%object4245%_)
                                             (_%object4387%_ _%object4316%_)
                                             (_%object4458%_ _%object4387%_)
                                             (_%object4529%_ _%object4458%_))
                                        _%principal-value4168%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28931)))
                       (cons 'action
                             (let ((__tmp28932
                                    (lambda (_%@4600%_)
                                      (let* ((_%object4668%_ _%@4600%_)
                                             (_%object4739%_ _%object4668%_)
                                             (_%object4810%_ _%object4739%_)
                                             (_%object4881%_ _%object4810%_)
                                             (_%object4952%_ _%object4881%_))
                                        _%action-value4169%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28932)))
                       (cons 'resource
                             (let ((__tmp28933
                                    (lambda (_%@5023%_)
                                      (let* ((_%object5091%_ _%@5023%_)
                                             (_%object5162%_ _%object5091%_)
                                             (_%object5233%_ _%object5162%_)
                                             (_%object5304%_ _%object5233%_)
                                             (_%object5375%_ _%object5304%_))
                                        _%resource-value4170%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28933)))
                       (cons 'context
                             (let ((__tmp28934
                                    (lambda (_%@5446%_)
                                      (let* ((_%object5514%_ _%@5446%_)
                                             (_%object5585%_ _%object5514%_)
                                             (_%object5656%_ _%object5585%_)
                                             (_%object5727%_ _%object5656%_)
                                             (_%object5798%_ _%object5727%_))
                                        _%context-value4171%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28934)))
                       (cons 'intent
                             (let ((__tmp28935
                                    (lambda (_%@5869%_)
                                      (let* ((_%object5937%_ _%@5869%_)
                                             (_%object6008%_ _%object5937%_)
                                             (_%object6079%_ _%object6008%_)
                                             (_%object6150%_ _%object6079%_)
                                             (_%object6221%_ _%object6150%_))
                                        _%intent-value4172%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28935)))
                       (cons 'handoff
                             (let ((__tmp28936
                                    (lambda (_%@6292%_)
                                      (let* ((_%object6360%_ _%@6292%_)
                                             (_%object6431%_ _%object6360%_)
                                             (_%object6502%_ _%object6431%_)
                                             (_%object6573%_ _%object6502%_)
                                             (_%object6644%_ _%object6573%_))
                                        _%handoff-value4173%_))))
                               (declare (not safe))
                               (##structure
                                clan/poo/object#$self-slot-spec::t
                                __tmp28936)))))
                (__tmp28929 (list)))
            (declare (not safe))
            (clan/poo/object#object:::init!__%
             '#f
             agentic-ai-lab/src/policy/cedar-authority#Request.
             __tmp28930
             __tmp28929
             __obj28808))
          __obj28808)))
    (define agentic-ai-lab/src/policy/cedar-authority#runtime-record
      (lambda _%fields4162%_
        (let ((_%result4164%_
               (let ()
                 (declare (not safe))
                 (make-hash-table__%
                  '#f
                  absent-value
                  absent-value
                  absent-value
                  absent-value
                  absent-value
                  absent-value
                  absent-value
                  absent-value))))
          (let ((__tmp28937
                 (lambda (_%field4166%_)
                   (let ((__tmp28939 (car _%field4166%_))
                         (__tmp28938 (cdr _%field4166%_)))
                     (declare (not safe))
                     (__hash-put! _%result4164%_ __tmp28939 __tmp28938)))))
            (declare (not safe))
            (##for-each __tmp28937 _%fields4162%_))
          _%result4164%_)))
    (define agentic-ai-lab/src/policy/cedar-authority#context->runtime
      (lambda (_%value4145%_)
        (if (let ()
              (declare (not safe))
              (##structure-instance-of?
               _%value4145%_
               'clan/poo/object#object::t))
            (let ((_%result4148%_
                   (let ()
                     (declare (not safe))
                     (make-hash-table__%
                      '#f
                      absent-value
                      absent-value
                      absent-value
                      absent-value
                      absent-value
                      absent-value
                      absent-value
                      absent-value))))
              (let ((__tmp28941
                     (lambda (_%field4150%_)
                       (agentic-ai-lab/src/policy/cedar-authority#require-value
                        '"Cedar context keys must be symbols"
                        (symbol? (car _%field4150%_))
                        (car _%field4150%_))
                       (let ((__tmp28943 (symbol->string (car _%field4150%_)))
                             (__tmp28942
                              (agentic-ai-lab/src/policy/cedar-authority#context->runtime
                               (cdr _%field4150%_))))
                         (declare (not safe))
                         (__hash-put! _%result4148%_ __tmp28943 __tmp28942))))
                    (__tmp28940
                     (let ()
                       (declare (not safe))
                       (clan/poo/object#.alist _%value4145%_))))
                (declare (not safe))
                (##for-each __tmp28941 __tmp28940))
              _%result4148%_)
            (if (or (string? _%value4145%_)
                    (boolean? _%value4145%_)
                    (exact-integer? _%value4145%_))
                _%value4145%_
                (if (list? _%value4145%_)
                    (list->vector
                     (let ()
                       (declare (not safe))
                       (##map agentic-ai-lab/src/policy/cedar-authority#context->runtime
                              _%value4145%_)))
                    (if (vector? _%value4145%_)
                        (list->vector
                         (let ((__tmp28944
                                (let ()
                                  (declare (not safe))
                                  (##vector->list _%value4145%_))))
                           (declare (not safe))
                           (##map agentic-ai-lab/src/policy/cedar-authority#context->runtime
                                  __tmp28944)))
                        (let ()
                          (declare (not safe))
                          (error '"Cedar context contains an unsupported value"
                                 _%value4145%_))))))))
    (define agentic-ai-lab/src/policy/cedar-authority#handoff->runtime
      (lambda (_%value4143%_)
        (agentic-ai-lab/src/policy/cedar-authority#runtime-record
         (cons '"sequence"
               (let ()
                 (declare (not safe))
                 (clan/poo/object#.ref _%value4143%_ 'sequence)))
         (cons '"payload_hex"
               (let ()
                 (declare (not safe))
                 (clan/poo/object#.ref _%value4143%_ 'payload-hex)))
         (cons '"semantic_root"
               (let ()
                 (declare (not safe))
                 (clan/poo/object#.ref _%value4143%_ 'semantic-root)))
         (cons '"before_execution_root"
               (let ()
                 (declare (not safe))
                 (clan/poo/object#.ref _%value4143%_ 'before-execution-root)))
         (cons '"after_execution_root"
               (let ()
                 (declare (not safe))
                 (clan/poo/object#.ref _%value4143%_ 'after-execution-root)))
         (cons '"observation_digest"
               (let ()
                 (declare (not safe))
                 (clan/poo/object#.ref _%value4143%_ 'observation-digest))))))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authority-snapshot->runtime
      (lambda (_%value4134%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"runtime projection requires an authority snapshot"
         (agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authority-snapshot?
          _%value4134%_)
         _%value4134%_)
        (let ((_%context4136%_
               (let ()
                 (declare (not safe))
                 (clan/poo/object#.ref _%value4134%_ 'context)))
              (_%proof4137%_
               (let ()
                 (declare (not safe))
                 (clan/poo/object#.ref _%value4134%_ 'proof-binding))))
          (agentic-ai-lab/src/policy/cedar-authority#runtime-record
           (cons '"schema_id" '"agentic-ai-lab.cedar-authority-snapshot.v1")
           (cons '"producer" '"agentic-ai-lab.scheme-control")
           (cons '"source" '"src/policy/cedar-authority.ss")
           (cons '"object_kind" '"cedar-authority-snapshot")
           (cons '"provenance"
                 (agentic-ai-lab/src/policy/cedar-authority#runtime-record
                  (cons '"composition_identity"
                        (let ()
                          (declare (not safe))
                          (clan/poo/object#.ref _%proof4137%_ 'composition)))
                  (cons '"profile_origin_digest"
                        (let ()
                          (declare (not safe))
                          (clan/poo/object#.ref
                           _%proof4137%_
                           'profile-origin)))
                  (cons '"certification_names"
                        (list->vector
                         (let ()
                           (declare (not safe))
                           (clan/poo/object#.ref
                            _%proof4137%_
                            'certification-names))))))
           (cons '"authority_id"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%context4136%_ 'authority)))
           (cons '"runtime_context_id"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%context4136%_ 'runtime-context)))
           (cons '"runtime_generation"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%context4136%_ 'generation)))
           (cons '"bundle_epoch"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%context4136%_ 'bundle-epoch)))
           (cons '"runtime_bundle_digest"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%context4136%_ 'runtime-bundle)))
           (cons '"profile_bundle_digest"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%proof4137%_ 'profile-bundle)))
           (cons '"independent_bundle_digest"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%proof4137%_ 'independent-bundle)))
           (cons '"capability_contract_digest"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%proof4137%_ 'capability-contract)))
           (cons '"policy_revision"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%context4136%_ 'policy-revision)))
           (cons '"revocation_epoch"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%context4136%_ 'revocation-epoch)))
           (cons '"schema_json"
                 (let ((__tmp28945
                        (let ()
                          (declare (not safe))
                          (clan/poo/object#.ref _%value4134%_ 'cedar-schema))))
                   (declare (not safe))
                   (clan/poo/object#.ref __tmp28945 'document)))
           (cons '"entities_json"
                 (let ((__tmp28946
                        (let ()
                          (declare (not safe))
                          (clan/poo/object#.ref _%value4134%_ 'entities))))
                   (declare (not safe))
                   (clan/poo/object#.ref __tmp28946 'document)))
           (cons '"policies"
                 (list->vector
                  (map (lambda (_%policy4139%_)
                         (agentic-ai-lab/src/policy/cedar-authority#runtime-record
                          (cons '"identity"
                                (let ()
                                  (declare (not safe))
                                  (clan/poo/object#.ref
                                   _%policy4139%_
                                   'identity)))
                          (cons '"source"
                                (let ()
                                  (declare (not safe))
                                  (clan/poo/object#.ref
                                   _%policy4139%_
                                   'source)))))
                       (let ()
                         (declare (not safe))
                         (clan/poo/object#.ref _%value4134%_ 'policies)))))
           (cons '"capabilities"
                 (list->vector
                  (map (lambda (_%capability4141%_)
                         (agentic-ai-lab/src/policy/cedar-authority#runtime-record
                          (cons '"action"
                                (let ()
                                  (declare (not safe))
                                  (clan/poo/object#.ref
                                   _%capability4141%_
                                   'action)))
                          (cons '"event_kind"
                                (let ()
                                  (declare (not safe))
                                  (clan/poo/object#.ref
                                   _%capability4141%_
                                   'event-kind)))))
                       (let ()
                         (declare (not safe))
                         (clan/poo/object#.ref
                          _%value4134%_
                          'capabilities)))))))))
    (define agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authorization-request->runtime
      (lambda (_%value4130%_)
        (agentic-ai-lab/src/policy/cedar-authority#require-value
         '"runtime projection requires a Cedar request"
         (agentic-ai-lab/src/policy/cedar-authority#agentic-ai-lab-cedar-authorization-request?
          _%value4130%_)
         _%value4130%_)
        (let ((_%context4132%_
               (let ()
                 (declare (not safe))
                 (clan/poo/object#.ref _%value4130%_ 'context))))
          (agentic-ai-lab/src/policy/cedar-authority#require-value
           '"context.agentic_ai_lab is reserved to the authority"
           (not (assq 'agentic_ai_lab
                      (let ()
                        (declare (not safe))
                        (clan/poo/object#.alist _%context4132%_))))
           _%context4132%_)
          (agentic-ai-lab/src/policy/cedar-authority#runtime-record
           (cons '"schema_id" '"agentic-ai-lab.cedar-authorization-request.v1")
           (cons '"principal"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%value4130%_ 'principal)))
           (cons '"action"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%value4130%_ 'action)))
           (cons '"resource"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%value4130%_ 'resource)))
           (cons '"context"
                 (agentic-ai-lab/src/policy/cedar-authority#context->runtime
                  _%context4132%_))
           (cons '"intent_digest"
                 (let ()
                   (declare (not safe))
                   (clan/poo/object#.ref _%value4130%_ 'intent)))
           (cons '"handoff"
                 (agentic-ai-lab/src/policy/cedar-authority#handoff->runtime
                  (let ()
                    (declare (not safe))
                    (clan/poo/object#.ref _%value4130%_ 'handoff))))))))))
