# Tier: Screenshot Reel

Render styled terminal frames from text and stitch into an animated GIF. Each frame shows one step of a CLI demo (command + output).

**Best for:** CLI tools shown as discrete steps (command -> output -> next command -> output). Also useful when VHS breaks on quoting or special characters.
**Output:** GIF (silicon PNGs stitched via ffmpeg)
**Label:** "Demo"
**Required tools:** silicon, ffmpeg

## Step 1: Write Demo Content

Create a text file with `---` delimiters between frames. Each frame shows the terminal state for one step:

Write to `[RUN_DIR]/demo-steps.txt`:

```
$ your-cli-command --flag value
Output line 1
Output line 2
Success: feature works correctly
---
$ your-cli-command --another-flag
Different output showing another aspect
Result: 42 items processed
---
$ your-cli-command --verify
All checks passed
```

**Tips:**
- Include the `$` prompt to show what the user types
- Keep each frame under ~80 characters wide for readability
- 3-5 frames is ideal -- enough to tell the story, not so many the GIF is huge
- Strip unicode characters that silicon's default font can't render (checkmarks, fancy arrows)

## Step 2: Render Each Frame

For each frame (split on `---` lines), write to a temporary text file and render through silicon:

```bash
silicon [RUN_DIR]/frame-001.txt -o [RUN_DIR]/frame-001.png --theme Dracula -l bash --pad-horiz 20 --pad-vert 20
```

Repeat for each frame, numbering sequentially (frame-001, frame-002, etc.).

## Step 3: Stitch into GIF

Use the capture pipeline script to normalize frame dimensions, stitch with two-pass palette, and auto-reduce if over 10 MB. Screenshot reels use 2.5 seconds per frame (less than browser reels since terminal frames are faster to read):

```bash
bash scripts/capture-evidence.sh stitch --duration 2.5 [RUN_DIR]/demo.gif [RUN_DIR]/frame-*.png
```

The script handles dimension normalization (silicon produces different widths based on content length), palette generation, and automatic frame reduction if the GIF exceeds limits.

**If silicon or ffmpeg fails** (rendering error, stitching error, empty output): fall back to static screenshots tier. Include the raw terminal output as a code block in the PR description instead. Label as "Terminal output", not "Screenshots".

## Step 4: Cleanup

Remove individual PNGs and text files. Keep only the final GIF for upload.

Proceed to `references/upload-and-approval.md`.
