[Home page](https://claude.com/)

Explore here

![](https://cdn.prod.website-files.com/68a44d4040f98a4adf2207b6/6903d22e13864f88ea55c2d8_b5c98d26c46edc43193e7f7e28a00633a538bb9c-1000x1000.svg)

# How    Claude    Code    works    in    large    codebases:    Best    practices    and    where    to    start

_The most successful Claude Code deployments share a set of recognizable patterns across configurations, tooling, and org structure. This article is part of_ **_Claude Code at scale_** _, a new series covering best practices for engineering organizations building with Claude Code at enterprise scale._

- Category







[Enterprise AI](https://claude.com/blog/category/enterprise-ai)

- Product









Claude Code

- Date



May 14, 2026

- Reading time





5



min

- Share

[Copy link](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#)

https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start


Claude Code is running in production across multi-million-line monorepos, decades-old legacy systems, distributed architectures spanning dozens of repositories, and at organizations with thousands of developers. These environments present challenges that smaller, simpler codebases don’t, whether that’s build commands that differ across every subdirectory or legacy code spread across folders with no shared root.

This article covers the patterns we've observed that have led to successful adoption of Claude Code at scale. We use “large codebase” to refer to a wide range of deployments: monorepos with millions of lines, legacy systems built over decades, dozens of microservices across separate repositories, or any combination of the above. That also includes codebases running on languages that teams don't always associate with AI coding tools, such as C, C++, C#, Java, PHP. (Claude Code performs better than most teams expect it to in those cases, particularly as of recent model releases.) While every large codebase deployment is shaped by its specific version control, team structure, and accumulated conventions, the patterns here generalize across them and are a good starting point for teams considering adopting Claude Code.

## How Claude Code navigates large codebases

Claude Code navigates a codebase the way a software engineer would: it traverses the file system, reads files, uses grep to find exactly what it needs, and follows references across the codebase. It operates locally on the developer’s machine and doesn’t require a codebase index to be built, maintained, or uploaded to a server.

RAG-powered AI coding tools work by embedding the entire codebase and retrieving relevant chunks at query time. At large scale, those systems can fail because embedding pipelines can’t keep up with active engineering teams. By the time a developer queries the index, it reflects the codebase as it previously existed weeks, days, or even hours before. Retrieval then returns a function the team renamed two weeks ago, or references a module that was deleted in the last sprint, with no indication that either is out of date.

Agentic search avoids those failure modes. There's no embedding pipeline or centralized index to maintain as thousands of engineers commit new code. Each developer's instance works from the live codebase.

But the approach has a tradeoff: it works best when Claude has enough starting context to know where to look. This means the quality of Claude's navigation is shaped by how well the codebase is set up, layering context with CLAUDE.md files and skills. If you ask it to find all instances of a vague pattern across a billion-line codebase, you’ll hit context-window limits before the work begins. Teams that invest in codebase setup see better results.

## The harness matters as much as the model

One of the most common misconceptions about Claude Code is that its capabilities are solely defined by the model used. Teams focus on a model’s benchmarks and how it performs on test tasks. In practice, the ecosystem built around the model—the harness—determines how Claude Code performs more than the model alone.

The harness is built from five extension points—CLAUDE.md files, hooks, skills, plugins, and MCP servers—each serving a different function. The order in which teams build them matters, as each layer builds on what came before. Two additional capabilities, LSP integrations and subagents, round out the setup. Below, we explain what each of these components and capabilities do:

[**CLAUDE.md**](https://code.claude.com/docs/en/memory) **files come first**. These are context files that Claude reads automatically at the start of every session: root file for the big picture, subdirectory files for local conventions. They give Claude the codebase knowledge it needs to do anything well. Because they load in every session regardless of the task, keeping them focused on what applies broadly will prevent them from becoming a drag on performance.

[**Hooks**](https://code.claude.com/docs/en/hooks-guide) **make the setup self-improving**. Most teams think of hooks as scripts that prevent Claude from doing something wrong, but their more valuable use is continuous improvement. A stop hook can reflect on what happened during a session and propose CLAUDE.md updates while the context is fresh. A start hook can load team-specific context dynamically so every developer gets the right setup for their module without manual configuration. For automated checks like linting and formatting, hooks enforce the rules deterministically and produce more consistent results than relying on Claude to remember an instruction.

[**Skills**](https://code.claude.com/docs/en/skills) **keep the right expertise available on-demand without bloating every session.** In a large codebase with dozens of task types, not all expertise needs to be present in every session. Skills solve this through [progressive disclosure](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), offloading specialized workflows and domain knowledge that would otherwise compete for context space and loading them only when the task calls for it. For example, a security review skill loads when Claude is assessing code for vulnerabilities, while a document processing skill loads when a code change is made and documentation needs to be updated.

Skills can also be scoped to specific paths so they only activate in the relevant part of the codebase. A team that owns a payments service can bind their deployment skill to that directory, so it never auto-loads when someone is working elsewhere in the monorepo.

[**Plugins**](https://code.claude.com/docs/en/plugins) **distribute what works.** One challenge with large codebases is that _good_ setups can stay tribal. A plugin bundles skills, hooks, and MCP configurations into a single installable package, so when a new engineer installs that plugin on day one, they will immediately have the same context and capabilities as those who have been using Claude already. Plugin updates can be distributed across the organization through [managed marketplaces](https://support.claude.com/en/articles/13837433-manage-claude-cowork-plugins-for-your-organization).

For example, a large retail organization we work with built a skill connecting Claude to their internal analytics platform so that business analysts could pull performance data without leaving their workflow. They distributed it as a plugin before the broad rollout to the business.

**Language server protocol (LSP) integrations give Claude the same navigation a developer has in their IDE.** Most large-codebase IDEs already have an LSP running, powering "go to definition" and "find all references." Surfacing this to Claude gives it symbol-level precision: it can follow a function call to its definition, trace references across files, and distinguish between identically named functions in different languages. Without it, Claude pattern-matches on text and can land on the wrong symbol. One enterprise software company we worked with deployed LSP integrations org-wide before their Claude Code rollout, specifically to make C and C++ navigation reliable at scale. For multi-language codebases, this is one of the highest-value investments.

**MCP servers extend everything.** MCP servers are how Claude connects to internal tools, data sources, and APIs that it can't otherwise reach. The most sophisticated teams built MCP servers exposing structured search as a tool Claude can call directly. Others connect Claude to internal documentation, ticketing systems, or analytics platforms.

[**Subagents**](https://code.claude.com/docs/en/sub-agents) **split exploration from editing.** A subagent is an isolated Claude instance with its own context window that takes a task, does the work, and returns only the final result to the parent. Once the harness is in place, some teams spin up a read-only subagent to map a subsystem and write findings to a file, then have the main agent edit with the full picture.

![](https://cdn.prod.website-files.com/68a44d4040f98a4adf2207b6/6a04aaf1c37c6196e5ee19bb_fig1-the-claude-code-harness-v1%402x.png)

_Claude Code’s extension layer at a glance._

The table below summarizes what each component does, when it loads, and the most common mistakes we see with each:

| Component | What it is | When it loads | Best for | Common confusion |
| --- | --- | --- | --- | --- |
| CLAUDE.md | Context file Claude reads automatically | Every session | Project-specific conventions, codebase knowledge | Using it for reusable expertise that belongs in a skill |
| Hooks | Scripts that run at key moments | Triggered by events | Automating consistent behavior, capturing session learnings | Using prompts for things that should run automatically |
| Skills | Packaged instructions for specific task types | On demand, when relevant | Reusable expertise across sessions and projects | Loading everything into CLAUDE.md instead |
| Plugins | Bundled skills, hooks, MCP configs | Always available once configured | Distributing a working setup across the org | Letting good setups stay tribal |
| Language server protocol (LSP)\* | Real-time code intelligence via language specific servers | Always available once configured | Symbol-level navigation and automatic error detection in typed languages | Assuming that it's automatic |
| MCP servers | Connections to external tools and data | Always available once configured | Giving Claude access to internal tools it can't otherwise reach | Building MCP connections before the basics are working |
| Subagents\* | Separate Claude instances for specific tasks | When invoked | Splitting exploration from editing, parallel work | Running exploration and editing in the same session |
| \*LSP is accessed through the plugin layer. Subagents are a delegation capability rather than a configured extension point. |

## Three configuration patterns from successful deployments

How you configure Claude Code for a large codebase depends heavily on how that codebase is structured. Still, three patterns appeared consistently across the deployments we observed.

### Making the codebase navigable at scale

Claude’s ability to help in a large codebase is bounded by its ability to find the right context. Too much context loaded into every session degrades performance, while too little context leaves Claude to navigate blind. The most effective deployments invest upfront in making the codebase legible to Claude. A few patterns appear consistently:

- **Keeping CLAUDE.md files lean and layered.** Claude loads them additively as it moves through the codebase: root file for the big picture, subdirectory files for local conventions. The root file should be pointers and critical gotchas only; everything else drifts into noise.
- **Initializing in subdirectories, not at the repo root.** Claude works best when it's scoped to the part of the codebase that's actually relevant to the task. In monorepos, this can feel counterintuitive because tooling often assumes root access, but Claude automatically walks up the directory tree and loads every CLAUDE.md file it finds along the way, so root-level context is never lost.
- **Scoping test and lint commands per subdirectory.** Running the full suite when Claude changed one service causes timeouts and wastes context on irrelevant output. CLAUDE.md files at the subdirectory level should specify the commands that apply to that part of the codebase. This works well for service-oriented codebases where each directory has its own test and build commands. In compiled-language monorepos with deep cross-directory dependencies, per-subdirectory scoping is harder to achieve and may require project-specific build configurations.
- **Using `.`**`ignore` **files to exclude generated files, build artifacts, and third-party code.** Committing `permissions.deny` rules in `.claude/settings.json` means the exclusions are version-controlled, so every developer on the team gets the same noise reduction without configuring it themselves. In some codebases, generated files are themselves the subject of development work. Developers who work on code generators can override project-level exclusions in their local settings without affecting the rest of the team.
- **Building codebase maps when the directory structure doesn’t do the work.** For organizations where code isn’t consolidated in a conventional directory structure, a lightweight markdown file at the repo root listing each top-level folder with a one-line description of what lives there gives Claude a table of contents it can scan before opening files. For codebases with hundreds of top-level folders, this works best as a layered approach: the root file describes only the highest-level structure, and subdirectory CLAUDE.md files provide the next level of detail, loading on demand as Claude moves through the tree. For simpler cases, @-mentioning the specific files or directories Claude should reference can do the same job.
- **Running LSP servers so Claude searches by symbol, not by string.** Grep for a common function name in a large codebase returns thousands of matches and Claude burns context opening files to figure out which matters. LSP returns only the references that point to the same symbol, so the filtering happens before Claude reads anything.Setting this up requires installing a [code intelligence plugin](https://code.claude.com/docs/en/discover-plugins#code-intelligence) for your language and the corresponding language server binary; the Claude Code documentation covers the available plugins and troubleshooting.

**One caveat**: there are edge cases where even the hierarchical CLAUDE.md approach breaks down, for example codebases with hundreds of thousands of folders and millions of files, or legacy systems on non-git version control. We will address their challenges in future installments of this series.

### Actively maintaining CLAUDE.md files as model intelligence evolves

As models evolve, instructions written for your current model can work against a future one. CLAUDE.md files that guided Claude through patterns it used to struggle with may either become unnecessary or actively constraining when the next model ships. For example, a CLAUDE.md rule that tells Claude to break every refactor into single-file changes may have helped an earlier model stay on track but would prevent a newer one from making coordinated cross-file edits it handles well.

Skills and hooks built to compensate for specific model limitations, whether in the model’s reasoning or in Claude Code’s own tooling, become overhead once those limitations no longer exist. A hook that intercepted file writes to enforce p4 edit in a Perforce codebase, for example, became redundant once Claude Code added native Perforce mode.

Teams should expect to do a meaningful configuration review every three to six months, but it's also worth doing one whenever performance feels like it's plateaued after major model releases.

### Assigning ownership for Claude Code management and adoption

Technical configuration alone doesn't drive adoption. The organizations that got it right invested in the organizational layer, too.

The rollouts that spread fastest had a dedicated infrastructure investment before broad access. A small team, sometimes even just one person, wired up the tooling so Claude already fit developer workflows when they first touched it. At one company, a couple of engineers built a suite of plugins and MCPs that were available on day one. At another, an entire team focused on managing AI coding tools had the infrastructure in place before the rollout began. In both cases, developers' first experience was productive rather than frustrating, and adoption spread from there.

![](https://cdn.prod.website-files.com/68a44d4040f98a4adf2207b6/6a04e25f1984beb50dc5525b_fig2-phases-of-claude-code-rollout-v1%402x.png)

The teams doing this work today tend to sit under developer experience or developer productivity, which is typically the function responsible for onboarding new engineers and building developer tooling. An emerging role in several organizations is an agent manager: a hybrid PM/engineer function dedicated to managing the Claude Code ecosystem. For organizations without a dedicated team, the minimum viable version is a DRI: one person with ownership over the Claude Code configuration, the authority to make calls on settings, permissions policy, the plugin marketplace, and CLAUDE.md conventions, and the responsibility to keep them current.

Bottoms-up adoption generates enthusiasm but can fragment without someone to centralize what works. You need to have an individual or a team assemble and evangelize the right Claude Code conventions (such as a standardized CLAUDE.md hierarchy or a curated set of skills and plugins). Without that work, knowledge will stay tribal and adoption will plateau.

In large organizations, especially those in regulated industries, governance questions come up early, such as: who controls which skills and plugins are available, how do you prevent thousands of engineers from independently rebuilding the same thing, how do you make sure AI-generated code goes through the same review process as human-generated code? To address these early on, we suggest starting with a defined set of approved skills, required code review processes, and limited initial access, and expand as confidence builds.

We’ve observed the smoothest deployments at organizations that establish cross-functional working groups early by bringing together engineering, information security, and governance representatives to define requirements together and build a rollout roadmap.

## Applying these patterns to your organization

Claude Code is designed around conventional software engineering environments where engineers are the primary codebase contributors, the repo uses Git, and code follows standard directory structures. Most large codebases fit this mold, but non-traditional setups such as game engines with large binary assets, environments with unconventional version control, or non-engineers contributing to the codebase require additional configuration work. Our guidance assumes a conventional setup and the patterns we’ve described have worked across many of our customers.  Any remaining complexity requires judgment specific to your codebase, tooling, and organization. That's where Anthropic's Applied AI team works directly with engineering teams to translate these patterns into your organization’s specific requirements.

![](https://cdn.prod.website-files.com/68a44d4040f98a4adf2207b6/6a04e2860abbe67418ca0f8b_fig3-getting-started-checklist-v2%402x.png)

_Get started with_ [_Claude Code for Enterprise_](https://claude.com/product/claude-code/enterprise) _._

‍

**_Acknowledgements:_** _Special thanks to Alon Krifcher, Charmaine Lee, Chris Concannon, Harsh Patel, Henrique Savelli, Jason Schwartz, Jonah Dueck and Kirby Kohlmorgen from Anthropic’s Applied AI team for sharing their experience deploying Claude Code at scale, and to Amit Navindgi at Zoox for providing feedback on this article._

‍

No items found.

[Prev](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) Prev

0/5

[Next](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) Next

eBook

![](https://cdn.prod.website-files.com/6889473510b50328dbb70ae6/6889473610b50328dbb70b58_placeholder.svg)

![](https://cdn.prod.website-files.com/6889473510b50328dbb70ae6/6889473610b50328dbb70b58_placeholder.svg)![](https://cdn.prod.website-files.com/6889473510b50328dbb70ae6/6889473610b50328dbb70b58_placeholder.svg)

FAQ

No items found.

## Related posts

Explore more product news and best practices for teams building with Claude.

![](https://cdn.prod.website-files.com/68a44d4040f98a4adf2207b6/6903d22c7f111435762ad994_1b398dbdfa4995ce5ce943aa87d8b78b2c2ba065-1000x1000.svg)

Jun 22, 2026

### The full Claude Desktop experience on AWS, Google Cloud, and Microsoft Foundry

Enterprise AI

[The full Claude Desktop experience on AWS, Google Cloud, and Microsoft Foundry](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) The full Claude Desktop experience on AWS, Google Cloud, and Microsoft Foundry

[The full Claude Desktop experience on AWS, Google Cloud, and Microsoft Foundry](https://claude.com/blog/the-full-claude-desktop-experience-on-aws-google-cloud-and-microsoft-foundry) The full Claude Desktop experience on AWS, Google Cloud, and Microsoft Foundry

![](https://cdn.prod.website-files.com/68a44d4040f98a4adf2207b6/6903d22930b7622d6096c33d_4d663bd87c391c144b9bca513b3849ccfa00a3b9-1000x1000.svg)

Mar 13, 2026

### 1M context is now generally available for Opus 4.6 and Sonnet 4.6

Product announcements

[1M context is now generally available for Opus 4.6 and Sonnet 4.6](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) 1M context is now generally available for Opus 4.6 and Sonnet 4.6

[1M context is now generally available for Opus 4.6 and Sonnet 4.6](https://claude.com/blog/1m-context-ga) 1M context is now generally available for Opus 4.6 and Sonnet 4.6

![](https://cdn.prod.website-files.com/68a44d4040f98a4adf2207b6/6903d2319ef2161fcf9ba649_ddad92700787ec1bf1d80359c0c5e6ca305682b0-1000x1000.svg)

Feb 5, 2026

### Advancing finance with Claude Opus 4.6

Enterprise AI

[Advancing finance with Claude Opus 4.6](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) Advancing finance with Claude Opus 4.6

[Advancing finance with Claude Opus 4.6](https://claude.com/blog/opus-4-6-finance) Advancing finance with Claude Opus 4.6

![](https://cdn.prod.website-files.com/68a44d4040f98a4adf2207b6/6903d223de65e7dcca8267d8_ea364001be6bf6d2e86b58109ead6a779d5771a7-1000x1000.svg)

Jul 24, 2025

### How Anthropic teams use Claude Code

Enterprise AI

[How Anthropic teams use Claude Code](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) How Anthropic teams use Claude Code

[How Anthropic teams use Claude Code](https://claude.com/blog/how-anthropic-teams-use-claude-code) How Anthropic teams use Claude Code

## Transform how your organization operates with Claude

See pricing

[See pricing](https://claude.com/pricing#api) See pricing

Contact sales

[Contact sales](https://claude.com/contact-sales) Contact sales

Get the developer newsletter

Product updates, how-tos, community spotlights, and more. Delivered monthly to your inbox.

[Subscribe](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) Subscribe

Please provide your email address if you'd like to receive our monthly developer newsletter. You can unsubscribe at any time.

Thank you! You’re subscribed.

Sorry, there was a problem with your submission, please try again later.

[Homepage](https://claude.com/) Homepage

[Next](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) Next

Thank you! Your submission has been received!

Oops! Something went wrong while submitting the form.

Write

[Button Text](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) Button Text

Learn

[Button Text](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) Button Text

Code

[Button Text](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start#) Button Text

Write

- Help me develop a unique voice for an audience











Hi Claude! Could you help me develop a unique voice for an audience? If you need more information from me, ask me 1-2 key questions right away. If you think I should upload any documents that would help you do a better job, let me know. You can use the tools you have access to— like Google Drive, web search, etc.—if they’ll help you better accomplish this task. Do not use analysis tool. Please keep your responses friendly, brief and conversational.



Please execute the task as soon as you can—an artifact would be great if it makes sense. If using an artifact, consider what kind of artifact (interactive, visual, checklist, etc.) might be most helpful for this specific task. Thanks for your help!

- Improve my writing style











Hi Claude! Could you improve my writing style? If you need more information from me, ask me 1-2 key questions right away. If you think I should upload any documents that would help you do a better job, let me know. You can use the tools you have access to— like Google Drive, web search, etc.—if they’ll help you better accomplish this task. Do not use analysis tool. Please keep your responses friendly, brief and conversational.



Please execute the task as soon as you can—an artifact would be great if it makes sense. If using an artifact, consider what kind of artifact (interactive, visual, checklist, etc.) might be most helpful for this specific task. Thanks for your help!

- Brainstorm creative ideas











Hi Claude! Could you brainstorm creative ideas? If you need more information from me, ask me 1-2 key questions right away. If you think I should upload any documents that would help you do a better job, let me know. You can use the tools you have access to— like Google Drive, web search, etc.—if they’ll help you better accomplish this task. Do not use analysis tool. Please keep your responses friendly, brief and conversational.



Please execute the task as soon as you can—an artifact would be great if it makes sense. If using an artifact, consider what kind of artifact (interactive, visual, checklist, etc.) might be most helpful for this specific task. Thanks for your help!


Learn

- Explain a complex topic simply











Hi Claude! Could you explain a complex topic simply? If you need more information from me, ask me 1-2 key questions right away. If you think I should upload any documents that would help you do a better job, let me know. You can use the tools you have access to— like Google Drive, web search, etc.—if they’ll help you better accomplish this task. Do not use analysis tool. Please keep your responses friendly, brief and conversational.



Please execute the task as soon as you can—an artifact would be great if it makes sense. If using an artifact, consider what kind of artifact (interactive, visual, checklist, etc.) might be most helpful for this specific task. Thanks for your help!

- Help me make sense of these ideas











Hi Claude! Could you help me make sense of these ideas? If you need more information from me, ask me 1-2 key questions right away. If you think I should upload any documents that would help you do a better job, let me know. You can use the tools you have access to— like Google Drive, web search, etc.—if they’ll help you better accomplish this task. Do not use analysis tool. Please keep your responses friendly, brief and conversational.



Please execute the task as soon as you can—an artifact would be great if it makes sense. If using an artifact, consider what kind of artifact (interactive, visual, checklist, etc.) might be most helpful for this specific task. Thanks for your help!

- Prepare for an exam or interview











Hi Claude! Could you prepare for an exam or interview? If you need more information from me, ask me 1-2 key questions right away. If you think I should upload any documents that would help you do a better job, let me know. You can use the tools you have access to— like Google Drive, web search, etc.—if they’ll help you better accomplish this task. Do not use analysis tool. Please keep your responses friendly, brief and conversational.



Please execute the task as soon as you can—an artifact would be great if it makes sense. If using an artifact, consider what kind of artifact (interactive, visual, checklist, etc.) might be most helpful for this specific task. Thanks for your help!


Code

- Explain a programming concept











Hi Claude! Could you explain a programming concept? If you need more information from me, ask me 1-2 key questions right away. If you think I should upload any documents that would help you do a better job, let me know. You can use the tools you have access to— like Google Drive, web search, etc.—if they’ll help you better accomplish this task. Do not use analysis tool. Please keep your responses friendly, brief and conversational.



Please execute the task as soon as you can—an artifact would be great if it makes sense. If using an artifact, consider what kind of artifact (interactive, visual, checklist, etc.) might be most helpful for this specific task. Thanks for your help!

- Look over my code and give me tips











Hi Claude! Could you look over my code and give me tips? If you need more information from me, ask me 1-2 key questions right away. If you think I should upload any documents that would help you do a better job, let me know. You can use the tools you have access to— like Google Drive, web search, etc.—if they’ll help you better accomplish this task. Do not use analysis tool. Please keep your responses friendly, brief and conversational.



Please execute the task as soon as you can—an artifact would be great if it makes sense. If using an artifact, consider what kind of artifact (interactive, visual, checklist, etc.) might be most helpful for this specific task. Thanks for your help!

- Vibe code with me











Hi Claude! Could you vibe code with me? If you need more information from me, ask me 1-2 key questions right away. If you think I should upload any documents that would help you do a better job, let me know. You can use the tools you have access to— like Google Drive, web search, etc.—if they’ll help you better accomplish this task. Do not use analysis tool. Please keep your responses friendly, brief and conversational.



Please execute the task as soon as you can—an artifact would be great if it makes sense. If using an artifact, consider what kind of artifact (interactive, visual, checklist, etc.) might be most helpful for this specific task. Thanks for your help!


More

- Write case studies











This is another test

- Write grant proposals











Hi Claude! Could you write grant proposals? If you need more information from me, ask me 1-2 key questions right away. If you think I should upload any documents that would help you do a better job, let me know. You can use the tools you have access to — like Google Drive, web search, etc. — if they’ll help you better accomplish this task. Do not use analysis tool. Please keep your responses friendly, brief and conversational.



Please execute the task as soon as you can - an artifact would be great if it makes sense. If using an artifact, consider what kind of artifact (interactive, visual, checklist, etc.) might be most helpful for this specific task. Thanks for your help!

- Write video scripts











this is a test


[Anthropic](https://www.anthropic.com/) Anthropic

© 2026 Anthropic PBC

Products

- Claude

[Claude](https://claude.com/product/overview) Claude

- Claude Code

[Claude Code](https://claude.com/product/claude-code) Claude Code

- Claude Code for Enterprise

[Claude Code for Enterprise](https://claude.com/product/claude-code/enterprise) Claude Code for Enterprise

- Claude Cowork

[Claude Cowork](https://claude.com/product/cowork) Claude Cowork

- Claude Design

[Claude Design](https://claude.com/product/design) Claude Design

- Claude Security

[Claude Security](https://claude.com/product/claude-security) Claude Security

- Download app

[Download app](https://claude.com/download) Download app

- Pricing

[Pricing](https://claude.com/pricing) Pricing

- Log in

[Log in](https://claude.ai/login) Log in


Features

- Claude for Chrome

[Claude for Chrome](https://claude.com/claude-for-chrome) Claude for Chrome

- Claude for Slack

[Claude for Slack](https://claude.com/claude-for-slack) Claude for Slack

- Claude for Microsoft 365

[Claude for Microsoft 365](https://claude.com/claude-for-microsoft-365) Claude for Microsoft 365

- Skills

[Skills](https://claude.com/skills) Skills


Models

- Mythos

[Mythos](https://www.anthropic.com/claude/mythos) Mythos

- Fable

[Fable](https://www.anthropic.com/claude/fable) Fable

- Opus

[Opus](https://www.anthropic.com/claude/opus) Opus

- Sonnet

[Sonnet](https://www.anthropic.com/claude/sonnet) Sonnet

- Haiku

[Haiku](https://www.anthropic.com/claude/haiku) Haiku


Solutions

- AI agents

[AI agents](https://claude.com/solutions/agents) AI agents

- Code modernization

[Code modernization](https://claude.com/solutions/code-modernization) Code modernization

- Coding

[Coding](https://claude.com/solutions/coding) Coding

- Customer support

[Customer support](https://claude.com/solutions/customer-support) Customer support

- Education

[Education](https://claude.com/solutions/education) Education

- Enterprise

[Enterprise](https://claude.com/solutions/enterprise) Enterprise

- Financial services

[Financial services](https://claude.com/solutions/financial-services) Financial services

- Government

[Government](https://claude.com/solutions/government) Government

- Healthcare

[Healthcare](https://claude.com/solutions/healthcare) Healthcare

- Legal

[Legal](https://claude.com/solutions/legal) Legal

- Life sciences

[Life sciences](https://claude.com/solutions/life-sciences) Life sciences

- Nonprofits

[Nonprofits](https://claude.com/solutions/nonprofits) Nonprofits

- Security

[Security](https://claude.com/solutions/security) Security

- Small business

[Small business](https://claude.com/solutions/small-business) Small business

- Startups

[Startups](https://claude.com/programs/startups) Startups


Claude Platform

- Overview

[Overview](https://claude.com/platform/api) Overview

- Developer docs

[Developer docs](https://platform.claude.com/docs) Developer docs

- Pricing

[Pricing](https://claude.com/pricing#api) Pricing

- Marketplace

[Marketplace](https://claude.com/platform/marketplace) Marketplace

- Claude on AWS

[Claude on AWS](https://claude.com/partners/claude-on-aws) Claude on AWS

- Google Cloud

[Google Cloud](https://claude.com/partners/google-cloud) Google Cloud

- Microsoft Foundry

[Microsoft Foundry](https://claude.com/partners/microsoft-foundry) Microsoft Foundry

- Regional compliance

[Regional compliance](https://claude.com/regional-compliance) Regional compliance

- Console login

[Console login](https://platform.claude.com/) Console login


Resources

- Blog

[Blog](https://claude.com/blog) Blog

- Claude partner network

[Claude partner network](https://claude.com/partners) Claude partner network

- Community

[Community](https://claude.com/community) Community

- Connectors

[Connectors](https://claude.com/connectors) Connectors

- Courses

[Courses](https://www.anthropic.com/learn) Courses

- Customer stories

[Customer stories](https://claude.com/customers) Customer stories

- Engineering at Anthropic

[Engineering at Anthropic](https://www.anthropic.com/engineering) Engineering at Anthropic

- Events

[Events](https://www.anthropic.com/events) Events

- Plugins

[Plugins](https://claude.com/plugins) Plugins

- Powered by Claude

[Powered by Claude](https://claude.com/partners/powered-by-claude) Powered by Claude

- Service partners

[Service partners](https://claude.com/partners/services) Service partners

- Tutorials

[Tutorials](https://claude.com/resources/tutorials) Tutorials

- Use cases

[Use cases](https://claude.com/resources/use-cases) Use cases


Company

- Anthropic

[Anthropic](https://www.anthropic.com/) Anthropic

- Careers

[Careers](https://www.anthropic.com/careers) Careers

- Policy

[Policy](https://www.anthropic.com/policy) Policy

- Economic Futures

[Economic Futures](https://www.anthropic.com/economic-futures) Economic Futures

- Research

[Research](https://www.anthropic.com/research) Research

- News

[News](https://www.anthropic.com/news) News

- Policy on the AI Exponential

[Policy on the AI Exponential](https://www.anthropic.com/policy-on-the-ai-exponential) Policy on the AI Exponential

- Responsible Scaling Policy

[Responsible Scaling Policy](https://www.anthropic.com/news/announcing-our-updated-responsible-scaling-policy) Responsible Scaling Policy

- Security and compliance

[Security and compliance](https://trust.anthropic.com/) Security and compliance

- Transparency

[Transparency](https://anthropic.com/transparency) Transparency


Help and security

- Availability

[Availability](https://www.anthropic.com/supported-countries) Availability

- Status

[Status](https://status.anthropic.com/) Status

- Support center

[Support center](https://support.claude.com/en/) Support center


Terms and policies

- Privacy choices











### Cookie settings




We use cookies to deliver and improve our services, analyze site usage, and if you agree, to customize or personalize your experience and market our services to you. You can read our Cookie Policy [here](https://www.anthropic.com/legal/cookies).





Customize cookie settings
Reject all cookies
Accept all cookies









###### Necessary



Enables security and basic functionality.





Required









###### Analytics



Enables tracking of site performance.





Off









###### Marketing



Enables ads personalization and tracking.





Off




Save preferences


- Privacy policy

[Privacy policy](https://www.anthropic.com/legal/privacy) Privacy policy

- Responsible disclosure policy

[Responsible disclosure policy](https://www.anthropic.com/responsible-disclosure-policy) Responsible disclosure policy

- Terms of service: Commercial

[Terms of service: Commercial](https://www.anthropic.com/legal/commercial-terms) Terms of service: Commercial

- Terms of service: Consumer

[Terms of service: Consumer](https://www.anthropic.com/legal/consumer-terms) Terms of service: Consumer

- Usage policy

[Usage policy](https://www.anthropic.com/legal/aup) Usage policy


[x.com](https://x.com/claudeai) x.com

[LinkedIn](https://www.linkedin.com/showcase/claude/) LinkedIn

[YouTube](https://www.youtube.com/@anthropic-ai) YouTube

[Instagram](https://www.instagram.com/claudeai) Instagram

English (US)

Claude Code

×