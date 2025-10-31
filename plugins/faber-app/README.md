---
plugin: software-engineering-team


    DIRECTOR - manages workflow
    agent: software-engineering-director
        alias: [directors of software engineering]


    
    PRODUCT OWNER - defines what to be done and how to measure success
    agent: software-product-manager
        alias: [pm]
        responsibilities:
            - Define product vision & goals
            - Create and prioritize product roadmap
            - Release planning
            - Post-release analysis & iteration



        command: roadmap-create


        command: roadmap-prioritize



    PROJECT MANAGER - manages / prioritizes work
    agent: software-engineering-manager
        alias: [project manager, scrum master]
        responsibilities:
            - sprint planning & tacking



    ARCHITECT - master planner
    agent: software-architect
        alias: [tech lead, engineering lead]
        responsibilities:
            - define technical architecture
            - select tech stack / frameworks




    DESIGNER - customer interface / design
    agent: software-ux-designer
        alias: [ui designer]

        command: wireframe-create
            alias: [design wireframe, design user flow]



    ENGINEER - builder / implementor
    agent: software-engineer
        alias: [software developer]
        responsibilities:
            - feature implementation / coding
            - code review & quality control

    
    TESTER - verifies work done to standards
    agent: software-qa-engineer
        alias: [test engineer]
        responsibilities:
            - automated testing & QA validation
            - 
        command: test-create
            skill: test-create-
        
        command: test-execute
            skill: test-execute-report-failure
        
        test-


    DEPLOYER - launch / deploy work
    agent: software-devops-engineer
        alias: [site reliability engineer, sre]
        responsibilities: 
            - CI/CD setup & deployments
            - Production monitoring & uptime

    MONITOR - tracks performance / success metrics



    CUSTOMER SUCCESS



    FEEDBACK - user feedback intake




---