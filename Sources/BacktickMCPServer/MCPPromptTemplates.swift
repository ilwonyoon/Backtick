import Foundation

struct MCPPromptTemplate: Equatable, Sendable {
    let name: String
    let description: String
    let arguments: [MCPPromptArgument]
    let bodyTemplate: String
}

struct MCPPromptArgument: Equatable, Sendable {
    let name: String
    let description: String
    let required: Bool
}

enum MCPPromptCatalog {
    static let all: [MCPPromptTemplate] = [triage, diagnose, execute, plan, review]

    static func template(named name: String) -> MCPPromptTemplate? {
        all.first { $0.name == name }
    }

    private static let sharedArguments: [MCPPromptArgument] = [
        MCPPromptArgument(
            name: "noteText",
            description: "The raw note text (or merged group text) to process.",
            required: true
        ),
        MCPPromptArgument(
            name: "repositoryName",
            description: "Repository name for context.",
            required: false
        ),
        MCPPromptArgument(
            name: "branch",
            description: "Branch name for context.",
            required: false
        ),
    ]

    static let triage = MCPPromptTemplate(
        name: "triage",
        description: "Classify and group Stack notes by function, intent, and difficulty.",
        arguments: sharedArguments,
        bodyTemplate: """
        You are a senior engineering triage analyst.

        ## Notes to classify

        {noteText}

        ## Context
        Repository: {repositoryName}
        Branch: {branch}

        ## Instructions

        1. Classify each note by function/intent (bug fix, feature, refactor, config, docs, test).
        2. Group related notes that should be addressed together.
           - Same intent but different modules = separate groups.
           - User should understand the group just from the title.
        3. For each group provide:
           - Title (clear, specific to module + problem)
           - Difficulty: trivial | easy | medium | hard | complex
           - Scope: single-file | multi-file | cross-module
        4. Suggest execution order (easy first, dependencies respected).
        5. Flag ambiguous notes needing clarification.

        Return structured JSON: groups array with title, difficulty, scope, noteIDs, executionOrder, rationale.
        """
    )

    static let diagnose = MCPPromptTemplate(
        name: "diagnose",
        description: "Perform root cause analysis on grouped notes without executing fixes.",
        arguments: sharedArguments,
        bodyTemplate: """
        You are a senior debugger performing root cause analysis.

        ## Problem Description

        {noteText}

        ## Context
        Repository: {repositoryName}
        Branch: {branch}

        ## Goal
        Identify the root cause. Do NOT execute fixes.

        ## Constraints
        - Present hypotheses ranked by likelihood
        - For each hypothesis: verification method (log, test, repro steps)
        - Distinguish symptoms from causes
        - Note missing information needed to confirm
        """
    )

    static let execute = MCPPromptTemplate(
        name: "execute",
        description: "Implement changes described in grouped notes step by step.",
        arguments: sharedArguments,
        bodyTemplate: """
        You are an implementer working in an existing codebase.

        ## Task

        {noteText}

        ## Context
        Repository: {repositoryName}
        Branch: {branch}

        ## Goal
        Implement the changes step by step.

        ## Constraints
        - Follow existing code patterns and conventions
        - Make minimal, focused changes
        - Verify each step compiles before proceeding
        - Update tests for affected code
        - Do not refactor unrelated code
        """
    )

    static let plan = MCPPromptTemplate(
        name: "plan",
        description: "Analyze design space and recommend an implementation approach.",
        arguments: sharedArguments,
        bodyTemplate: """
        You are a software architect analyzing a design problem.

        ## Problem

        {noteText}

        ## Context
        Repository: {repositoryName}
        Branch: {branch}

        ## Goal
        Analyze the design space and recommend an approach.

        ## Deliverables
        - 2-3 viable approaches with trade-offs
        - Risks and dependencies for each
        - Recommended approach with justification
        - Implementation phases
        - Architectural concerns or breaking changes
        """
    )

    static let review = MCPPromptTemplate(
        name: "review",
        description: "Review changes for correctness, maintainability, and safety.",
        arguments: sharedArguments,
        bodyTemplate: """
        You are a code reviewer examining changes.

        ## Changes to Review

        {noteText}

        ## Context
        Repository: {repositoryName}
        Branch: {branch}

        ## Goal
        Review for correctness, maintainability, and safety.

        ## Classification
        - CRITICAL: Must fix (bugs, security, data loss)
        - HIGH: Should fix (performance, error handling)
        - MEDIUM: Recommended (style, naming)
        - LOW: Optional (nits)
        """
    )
}
