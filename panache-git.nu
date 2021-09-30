# An opinionated Git prompt for Nushell, styled after posh-git
def panache-git [] { (panache-git prompt) }

# Return the logical opposite of each Boolean expression in the pipeline
def nope [] { each { $it == $false } }

# Get repository status as raw text, generated by the "git status" command
def "panache-git raw" [] { do --ignore-errors { git --no-optional-locks status --porcelain=2 --branch } | str collect }

# Get repository status as a structured table
def "panache-git structured" [] {
  let status = (panache-git raw)

  let in-git-repo = ($status | empty? | nope)

  let on-named-branch = (if $in-git-repo
    { $status | lines | where ($it | str starts-with "# branch.head") | str contains "(detached)" | nope }
    { $false }
  )

  let branch-name = (if $on-named-branch
    { $status | lines | where ($it | str starts-with "# branch.head") | split column " " col1 col2 branch | get branch }
    { "" }
  )

  let commit-hash = (if $in-git-repo
    { $status | lines | where ($it | str starts-with "# branch.oid") | split column " " col1 col2 full_hash | get full_hash | str substring [0 7] }
    { "" }
  )

  let tracking-upstream-branch = (if $in-git-repo
    { $status | lines | where ($it | str starts-with "# branch.upstream") | str collect | empty? | nope }
    { $false }
  )

  let upstream-exists-on-remote = (if $in-git-repo
    { $status | lines | where ($it | str starts-with "# branch.ab") | str collect | empty? | nope }
    { $false }
  )

  let ahead-behind-table = (if $upstream-exists-on-remote
    { $status | lines | where ($it | str starts-with "# branch.ab") | split column " " col1 col2 ahead behind }
    { [[];[]] }
  )

  let commits-ahead = (if $upstream-exists-on-remote
    { $ahead-behind-table | get ahead | str to-int }
    { 0 }
  )

  let commits-behind = (if $upstream-exists-on-remote
    { $ahead-behind-table | get behind | str to-int | math abs }
    { 0 }
  )

  let has-staging-or-worktree-changes = (if $in-git-repo
    { $status | lines | where ($it | str starts-with "1") || ($it | str starts-with "2") | str collect | empty? | nope }
    { $false }
  )

  let has-untracked-files = (if $in-git-repo
    { $status | lines | where ($it | str starts-with "?") | str collect | empty? | nope }
    { $false }
  )

  let has-unresolved-merge-conflicts = (if $in-git-repo
    { $status | lines | where ($it | str starts-with "u") | str collect | empty? | nope }
    { $false }
  )

  let staging-worktree-table = (if $has-staging-or-worktree-changes
    { $status | lines | where ($it | str starts-with "1") || ($it | str starts-with "2") | split column " " | get Column2 | split column "" staging worktree --collapse-empty }
    { [[];[]] }
  )

  let staging-added-count = (if $has-staging-or-worktree-changes
    { $staging-worktree-table | where staging == "A" | length }
    { 0 }
  )

  let staging-modified-count = (if $has-staging-or-worktree-changes
    { $staging-worktree-table | where staging in ["M", "R"] | length }
    { 0 }
  )

  let staging-deleted-count = (if $has-staging-or-worktree-changes
    { $staging-worktree-table | where staging == "D" | length }
    { 0 }
  )

  let untracked-count = (if $has-untracked-files
    { $status | lines | where ($it | str starts-with "?") | length }
    { 0 }
  )

  let worktree-modified-count = (if $has-staging-or-worktree-changes
    { $staging-worktree-table | where worktree in ["M", "R"] | length }
    { 0 }
  )

  let worktree-deleted-count = (if $has-staging-or-worktree-changes
    { $staging-worktree-table | where worktree == "D" | length }
    { 0 }
  )

  let merge-conflict-count = (if $has-unresolved-merge-conflicts
    { $status | lines | where ($it | str starts-with "u") | length }
    { 0 }
  )

  [
    [in_git_repo,  on_named_branch,  branch_name,  commit_hash,  tracking_upstream_branch,  upstream_exists_on_remote,  commits_ahead,  commits_behind,  staging_added_count,  staging_modified_count,  staging_deleted_count,  untracked_count,  worktree_modified_count,  worktree_deleted_count,  merge_conflict_count];
    [$in-git-repo, $on-named-branch, $branch-name, $commit-hash, $tracking-upstream-branch, $upstream-exists-on-remote, $commits-ahead, $commits-behind, $staging-added-count, $staging-modified-count, $staging-deleted-count, $untracked-count, $worktree-modified-count, $worktree-deleted-count, $merge-conflict-count]
  ]
}

# Get repository status as a styled string
def "panache-git styled" [] {

  def bright-cyan [] { each { $"(ansi -e '96m')($it)(ansi reset)" } }
  def bright-green [] { each { $"(ansi -e '92m')($it)(ansi reset)" } }
  def bright-red [] { each { $"(ansi -e '91m')($it)(ansi reset)" } }
  def bright-yellow [] { each { $"(ansi -e '93m')($it)(ansi reset)" } }
  def green [] { each { $"(ansi green)($it)(ansi reset)" } }
  def red [] { each { $"(ansi red)($it)(ansi reset)" } }

  def branch-local-only [
    branch: string
  ] {
    $branch | bright-cyan
  }

  def branch-upstream-deleted [
    branch: string
  ] {
    $"($branch ) (char failed)" | bright-cyan
  }

  def branch-up-to-date [
    branch: string
  ] {
    $"($branch) (char identical_to)" | bright-cyan
  }

  def branch-ahead [
    branch: string
    ahead: int
  ] {
    $"($branch) (char branch_ahead)($ahead)" | bright-green
  }

  def branch-behind [
    branch: string
    behind: int
  ] {
    $"($branch) (char branch_behind)($behind)" | bright-red
  }

  def branch-ahead-and-behind [
    branch: string
    ahead: int
    behind: int
  ] {
    $"($branch) (char branch_behind)($behind) (char branch_ahead)($ahead)" | bright-yellow
  }

  def staging-changes [
    added: int
    modified: int
    deleted: int
  ] {
    $"+($added) ~($modified) -($deleted)" | green
  }

  def worktree-changes [
    added: int
    modified: int
    deleted: int
  ] {
    $"+($added) ~($modified) -($deleted)" | red
  }

  def unresolved-conflicts [
    conflicts: int
  ] {
    $"!($conflicts)" | red
  }

  let status = (panache-git structured)

  let is-local-only = ($status.tracking_upstream_branch != $true)

  let upstream-deleted = (
    $status.tracking_upstream_branch &&
    $status.upstream_exists_on_remote != $true
  )

  let is-up-to-date = (
    $status.upstream_exists_on_remote &&
    $status.commits_ahead == 0 &&
    $status.commits_behind == 0
  )

  let is-ahead = (
    $status.upstream_exists_on_remote &&
    $status.commits_ahead > 0 &&
    $status.commits_behind == 0
  )

  let is-behind = (
    $status.upstream_exists_on_remote &&
    $status.commits_ahead == 0 &&
    $status.commits_behind > 0
  )

  let is-ahead-and-behind = (
    $status.upstream_exists_on_remote &&
    $status.commits_ahead > 0 &&
    $status.commits_behind > 0
  )

  let branch-name = (if $status.in_git_repo
    {
      (if $status.on_named_branch
        { $status.branch_name }
        { [ "(", $status.commit_hash, "...)" ] | str collect }
      )
    }
    { "" }
  )

  let branch-styled = (if $status.in_git_repo
    {
      (if $is-local-only
        { (branch-local-only $branch-name) }
        {
          (if $is-up-to-date
            { (branch-up-to-date $branch-name) }
            {
              (if $is-ahead
                { (branch-ahead $branch-name $status.commits_ahead) }
                {
                  (if $is-behind
                    { (branch-behind $branch-name $status.commits_behind) }
                    {
                      (if $is-ahead-and-behind
                        { (branch-ahead-and-behind $branch-name $status.commits_ahead $status.commits_behind) }
                        {
                          (if $upstream-deleted
                            { (branch-upstream-deleted $branch-name) }
                            { $branch-name }
                          )
                        }
                      )
                    }
                  )
                }
              )
            }
          )
        }
      )
    }
    { "" }
  )

  let has-staging-changes = (
    $status.staging_added_count > 0 ||
    $status.staging_modified_count > 0 ||
    $status.staging_deleted_count > 0
  )

  let has-worktree-changes = (
    $status.untracked_count > 0 ||
    $status.worktree_modified_count > 0 ||
    $status.worktree_deleted_count > 0 ||
    $status.merge_conflict_count > 0
  )

  let has-merge-conflicts = $status.merge_conflict_count > 0

  let staging-summary = (if $has-staging-changes
    { (staging-changes $status.staging_added_count $status.staging_modified_count $status.staging_deleted_count) }
    { "" }
  )

  let worktree-summary = (if $has-worktree-changes
    { (worktree-changes $status.untracked_count $status.worktree_modified_count $status.worktree_deleted_count) }
    { "" }
  )

  let merge-conflict-summary = (if $has-merge-conflicts
    { (unresolved-conflicts $status.merge_conflict_count) }
    { "" }
  )

  let delimiter = (if ($has-staging-changes && $has-worktree-changes)
    { ("|" | bright-yellow) }
    { "" }
  )

  let local-summary = ($"($staging-summary) ($delimiter) ($worktree-summary) ($merge-conflict-summary)" | str trim)

  let local-indicator = (if $status.in_git_repo
    {
      (if $has-worktree-changes
        { ("!" | red) }
        {
          (if $has-staging-changes
            { ("~" | bright-cyan) }
            { "" }
          )
        }
      )
    }
    { "" }
  )

  let repo-summary = ($"($branch-styled) ($local-summary) ($local-indicator)" | str trim)

  (if $status.in_git_repo
    { $"('[' | bright-yellow)($repo-summary)(']' | bright-yellow)" }
    { "" }
  )
}

# Get the panache-git shell prompt. The default subcommand invoked by "panache-git".
def "panache-git prompt" [] {
  let current-dir = (pwd)

  let current-dir-relative-to-home = (do --ignore-errors { $current-dir | path relative-to $nu.home-dir } | str collect)

  let in-sub-dir-of-home = ($current-dir-relative-to-home | empty? | nope)

  let current-dir-abbreviated = (if $in-sub-dir-of-home
    { $"~(char separator)($current-dir-relative-to-home)" }
    { $current-dir }
  )

  let prompt = ($"($current-dir-abbreviated) (panache-git styled)" | str trim)

  $"($prompt)> "
}
