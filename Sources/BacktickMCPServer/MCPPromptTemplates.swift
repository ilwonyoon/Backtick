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
        description: "Classify, group, and plan execution for Stack notes with safety checks.",
        arguments: sharedArguments,
        bodyTemplate: """
        You are a senior engineering triage analyst. Your job is to organize raw notes into safe, reviewable execution groups — not to execute anything.

        ## Notes to classify

        {noteText}

        ## Context
        Repository: {repositoryName}
        Branch: {branch}

        ## Classification Rules

        1. **Group by functional surface**, not just intent. Same intent (e.g. "bug fix") but different modules = separate groups. User should understand the group just from the title.
        2. **Assign a group type** to each group:
           - `implement` — clear task, ready to execute
           - `investigate` — needs exploration before action
           - `refine` — existing work needs iteration
           - `follow-up` — depends on another group completing first
           - `decision-needed` — ambiguous, requires user input before proceeding
        3. **Do NOT over-interpret notes.** If a note is exploratory, speculative, or ambiguous, classify it as `investigate` or `decision-needed`. Never promote a vague thought into a definitive `implement` task.
        4. **Assign confidence** (high / medium / low) to each group. Low confidence = auto-execution forbidden.

        ## Priority & Ordering

        Assign a shallow priority tier to each group:
        - `must_do_now` — blocking, urgent, or prerequisite for others
        - `should_do` — valuable, clear, not blocking
        - `later` — nice to have, exploratory, or waiting on decisions

        Suggest execution order: must_do_now first, then should_do by ascending difficulty, then later. Respect dependencies between groups.

        ## Execution Topology

        For each group, assess:
        - **Surface overlap**: does this group touch the same files/modules as another group?
        - **Dependency**: does this group depend on another completing first?
        - **Branch strategy**: `same-branch` (tiny, same flow) | `separate-branch` (independent, reviewable) | `separate-worktree` (parallel, needs isolation) | `must-serialize` (strict ordering required)
        - **Merge order**: independent | merge-after-group-X
        - **Commit checkpoints**: suggested commit boundaries within the group

        Only recommend `separate-worktree` for high-risk parallel work. Default to `separate-branch`.

        ## Output Format

        Return structured JSON:
        ```json
        {
          "groups": [
            {
              "title": "string — clear, specific to module + problem",
              "type": "implement | investigate | refine | follow-up | decision-needed",
              "confidence": "high | medium | low",
              "priority": "must_do_now | should_do | later",
              "difficulty": "trivial | easy | medium | hard | complex",
              "scope": "single-file | multi-file | cross-module",
              "noteIDs": ["uuid", ...],
              "sourceExcerpts": ["first 80 chars of each source note..."],
              "rationale": "why these notes belong together",
              "executionOrder": 1,
              "topology": {
                "branchStrategy": "same-branch | separate-branch | separate-worktree | must-serialize",
                "dependsOn": null,
                "mergeOrder": "independent | merge-after-group-X",
                "surfaceOverlap": ["group titles that touch same files"],
                "commitCheckpoints": ["step1", "step2"]
              }
            }
          ],
          "ungrouped": ["noteIDs that don't fit any group"],
          "warnings": ["any ambiguities or risks detected"]
        }
        ```
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
