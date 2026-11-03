# The boreal, listening

An exhibit-style 3D gallery of boreal ARU recordings from WildTrax, arranged on a
map and a season clock. Click a light to hear its 30-second clip.

## Folder layout

```
index.html                  the whole page (three.js loads from a CDN)
data/gallery_manifest.json  one entry per recording
clips/                      the 30 s MP3s named in the manifest
.nojekyll                   tells GitHub Pages to serve files as-is
```

The manifest in `data/` is a **placeholder**: entries have `"file": null`, so the
page plays synthesized sounds. When a real manifest and clips are in place, the page
plays the recordings with no code changes.

## Swapping in real data

1. Run `wildtrax_gallery_clips.R`. It writes `gallery_audio/clips/*.mp3` and
   `gallery_audio/gallery_manifest.json`.
2. Copy the MP3s into `clips/` and replace `data/gallery_manifest.json`.
3. Listen through for human voices and delete those clips (and their rows).
4. Commit and push.

## Publishing on GitHub Pages

1. Create a new **public** repository on GitHub, e.g. `boreal-soundscape`.
2. Upload this folder's contents (drag and drop on the repo page works, or use
   GitHub Desktop / `git push`).
3. Repo **Settings → Pages**: Source = *Deploy from a branch*, Branch = `main`, folder = `/ (root)`. Save.
4. After a minute or two the site is live at `https://<username>.github.io/boreal-soundscape/`.

## Previewing locally

Browsers block `fetch()` from `file://`, so opening `index.html` directly shows the
built-in placeholder set instead of the manifest. To preview the real manifest:

```
cd boreal-soundscape
python -m http.server 8000
```

then open http://localhost:8000.

## Before going public

- Confirm each WildTrax project's admins are OK with public audio.
- Coordinates are rounded to 0.01° (~1 km). Buffer further for sensitive sites.
- Keep the repo under ~1 GB; 300 clips at 64 kbps is about 70 MB.
