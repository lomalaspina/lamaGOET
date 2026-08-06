# Merging this work

Written for whoever reviews and merges these changes. No git expertise assumed.

## The short version

This branch fixes bugs and makes lamaGOET run on macOS. It also deletes the old
gtkdialog interface. If you want the fixes but not the deletion, you can take
part of it — see "Taking only some of it" below.

**It targets `cleanup`, not `master`.** `master` has not moved since November
2020; `cleanup` is where the work is. If the pull request shows a thousand
files, it is aimed at the wrong branch.

## Before you merge: check it works for you

Merging changes nothing until you push, so it is safe to try first.

```bash
git fetch https://github.com/dylan-jayatilaka/lamaGOET.git macos-qt-fixes
git checkout -b try-macos FETCH_HEAD
```

That puts the proposed code in a scratch branch. Your own branches are
untouched.

Run the tests:

```bash
bash Tests/run_all.sh
```

Sixteen should pass. Then run a real refinement — this is the part that
matters, because no test performs one:

```bash
cd examples/1-epoxide
bash ../../lamaGOET.sh --run-job-options ./job_options.txt
grep -A8 "IAM refinement" my_job.lst
```

Expect `R(F) 0.035630` with 44 parameters, against the 0.0355 published in the
2024 lab notes. Ten seconds, Tonto only.

**Please also run one job on the cluster.** Five of the fixes are in the cluster
runner and could not be tested here. A Gaussian job with self-consistent
cluster charges exercises the most important one.

When you are done looking:

```bash
git checkout cleanup
git branch -D try-macos
```

## Merging it

On GitHub, press **Merge pull request** on the PR. That is all.

From the command line instead:

```bash
git checkout cleanup
git pull https://github.com/dylan-jayatilaka/lamaGOET.git macos-qt-fixes
git push origin cleanup
```

## Taking only some of it

The commits are ordered so the uncontroversial ones come first. Commits 1–11
are portability and bug fixes; the interface deletion is commit 12.

To take the fixes and stop before the deletion:

```bash
git checkout cleanup
git merge 337c655        # everything up to and including the Tonto notes
git push origin cleanup
```

Or take single commits:

```bash
git cherry-pick 44938c9   # the five cluster bug fixes
git cherry-pick f2781e9   # macOS support
```

## If something goes wrong

Nothing is lost. Before merging, note where you are:

```bash
git rev-parse cleanup
```

If you merged and want to undo it, and **have not pushed yet**:

```bash
git reset --hard <that number>
```

If you have already pushed, make a new commit undoing it rather than rewriting
history others may have pulled:

```bash
git revert -m 1 <the merge commit>
git push origin cleanup
```

## What to look at closely

Three changes alter what lamaGOET computes. The rest is portability, deletion
and documentation.

1. **`44938c9` — five cluster-only bugs.** The important one: cluster Gaussian
   jobs with self-consistent cluster charges were reading
   `gaussian-point-charges`, a file nothing creates, so the point charges were
   silently dropped and those refinements ran without their crystal
   environment. Results from such jobs are suspect.

2. **`f2659d8` — a removed Tonto keyword.** `thermal_smearing_model=` no longer
   exists, so every job failed at the first cycle. Deleted rather than renamed;
   `partition_model=`, written on the next line, already covers it.
   `docs/TONTO_COMPATIBILITY.md` explains why.

3. **`d4a0656` — the summary file.** A job started from a Tonto IAM was not
   recording the IAM result, so the IAM-versus-HAR comparison could not be made
   from `<my_job>.lst`.

## What is not covered

- No automated test runs a refinement. The suite proves the machinery is
  intact, not that the numbers are right.
- Nothing was tested on a cluster; there was no `qsub` available.
- Windows is unverified beyond file encodings and path handling.
- The per-cycle convergence table in `<my_job>.lst` is still blank. The cause is
  known and recorded in `docs/TONTO_COMPATIBILITY.md`; the fix needs a
  different heading per refinement phase and was left alone.
