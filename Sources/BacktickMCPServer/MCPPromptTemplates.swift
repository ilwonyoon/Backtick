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
    static let all: [MCPPromptTemplate] = [workflow, triage, diagnose, execute]

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

    static let workflow = MCPPromptTemplate(
        name: "workflow",
        description: "Playbook for using Backtick Stack tools. Read this first to understand available workflows.",
        arguments: [],
        bodyTemplate: """
        You are an assistant connected to Backtick Stack, a note capture system for developers.

        ## Available Workflows

        Map the user's natural language request to one of these workflows:

        ### "정리해줘" / "triage" / "organize my notes"
        1. `classify_notes` (scope: active, groupBy: repository) — see what's there
        2. Use the **triage** prompt with the note texts — get grouping suggestions
        3. Show the suggested groups to the user and wait for confirmation
        4. `group_notes` for each confirmed group — merges into one card per group
        5. Source notes stay active. Only `mark_notes_executed` after real work is done.

        ### "이거 왜 그래" / "diagnose" / "why is this broken"
        1. Identify relevant notes (via `classify_notes` or `list_notes`)
        2. Use the **diagnose** prompt — root cause analysis only, no fixes
        3. Present hypotheses to the user

        ### "이거 해줘" / "execute" / "implement this"
        1. Identify relevant notes (via `classify_notes` or `list_notes`)
        2. Use the **execute** prompt — step-by-step implementation
        3. After verified implementation, `mark_notes_executed` on the source notes

        ### "현황" / "status" / "what do I have"
        1. `classify_notes` (scope: active) — summarize groups and counts
        2. Present a brief overview, no action needed

        ## Rules
        - Only process **active** notes. Copied notes are already executed.
        - `group_notes` merges cards but keeps originals active. Archiving is separate.
        - Never `mark_notes_executed` until the user confirms the work is done.
        - When unsure whether to diagnose or execute, default to diagnose.
        - Show results before taking further action. Never chain silently.
        """
    )

    static let triage = MCPPromptTemplate(
        name: "triage",
        description: "Classify and group Stack notes for review before execution.",
        arguments: sharedArguments,
        bodyTemplate: """
        You are an engineering triage assistant.

        ## Notes

        {noteText}

        ## Context
        Repository: {repositoryName}
        Branch: {branch}

        ## Instructions

        1. Group related notes that should be addressed together.
           - Same intent but different modules = separate groups.
           - User should understand the group just from the title.
        2. For each group: title, intent tag (diagnose/execute/investigate), difficulty (easy/medium/hard).
        3. If a note is ambiguous or exploratory, tag it as investigate — do not promote to execute.
        4. Suggest processing order: easy first, respect dependencies.

        Return JSON: { groups: [{ title, intent, difficulty, noteIDs, rationale }] }
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
        - Hypotheses ranked by likelihood
        - Each hypothesis: verification method (log, test, repro steps)
        - Distinguish symptoms from causes
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
        - Follow existing code patterns
        - Minimal, focused changes
        - Verify each step compiles
        - Do not refactor unrelated code
        """
    )
}
