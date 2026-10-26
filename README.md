<div align="center">
  <img src="assets/trimwasp.png" alt="TrimWasp wasp icon" width="150">
  <h1>TrimWasp</h1>
  <h3>Quick cuts. Tiny footprint.</h3>
  <p>A focused desktop video clipper. Mark your moments, queue your clips, and export them together.</p>
  <p><strong>Clean interface &middot; Local processing &middot; Batch exports</strong></p>
  <p>
    <img src="assets/macos.svg" alt="macOS 13 or newer" height="28">
    <img src="assets/windows.svg" alt="Windows 10 and 11, x64" height="28">
  </p>
</div>

<hr>
<h2>How to Build on MacOS</h2>
<p>Download the .zip, and extract it. Then navigate to 'TrimWasp-Mac' to ensure it downloaded properly. Then, open terminal, and run this command: </p>
<code>bash PathToFolder/TrimWasp-Mac/Build.command</code>
<p></p>
<p>Then, the application should open. Once opened successfully, you can locate the built application in the <code>./TrimWasp-Mac/build/TrimWasp</code>, and drag it into your applications folder if you please.
<p>Too many steps, or don't want to build it yourself? Check out the releases to get the pre-built latest release!</p>

<h2>Just the cuts you need</h2>
<p>TrimWasp keeps video clipping simple. Load your footage, mark the parts worth keeping, and export each selection as its own file. A clean timeline, a flexible workspace, and a handful of shortcuts keep everything within reach.</p>
<p><strong>No accounts. No subscriptions. No cloud uploads. No crowded editing workspace.</strong></p>

<h2>Small by design</h2>
<ul>
  <li><strong>Native desktop interfaces.</strong> No Electron or embedded browser.</li>
  <li><strong>Load what you need.</strong> Prepare a gallery of MP4 files, preview their thumbnails and details, then import one video when you are ready to work.</li>
  <li><strong>Focused previews.</strong> Small thumbnails, a bounded filmstrip, and background decoding keep media preparation manageable.</li>
  <li><strong>Skip unnecessary encoding.</strong> Original Quality mode copies the selected media without re-encoding, making exports fast while preserving the encoded video quality.</li>
</ul>
<p>Download size, memory use, and export speed depend on the platform and footage.</p>

<h2>Everything you need, nothing in the way</h2>
<table>
  <thead><tr><th>Feature</th><th>What it does</th></tr></thead>
  <tbody>
    <tr><td><strong>Multiple clips, one source</strong></td><td>Queue as many selections as you need from the imported video.</td></tr>
    <tr><td><strong>Batch export</strong></td><td>Save each queued selection as an individual video file.</td></tr>
    <tr><td><strong>Simple markers</strong></td><td>Press <kbd>M</kbd> or double-click the timeline to place two markers, in either order.</td></tr>
    <tr><td><strong>Easy adjustments</strong></td><td>Click a queued clip, drag its markers, and confirm with <strong>Update Clip</strong>.</td></tr>
    <tr><td><strong>Clear timeline</strong></td><td>See source frames and queued ranges; overlapping clips appear in separate lanes.</td></tr>
    <tr><td><strong>Flexible workspace</strong></td><td>Resize the media gallery, details panel, and timeline to suit your screen.</td></tr>
    <tr><td><strong>Folder and file loading</strong></td><td>Prepare a folder of MP4s, selected files, or a mixture of both.</td></tr>
    <tr><td><strong>Useful sorting</strong></td><td>Sort by name, creation date, modification date, size, or folder path.</td></tr>
    <tr><td><strong>Playback control</strong></td><td>Step through frames or review footage at <strong>0.1&times;&ndash;8&times;</strong> speed.</td></tr>
    <tr><td><strong>Save your selections</strong></td><td>Save a clip list and reopen it later alongside the original source video.</td></tr>
  </tbody>
</table>

<h2>From footage to finished clips</h2>
<ol>
  <li><strong>Load Files</strong> &mdash; choose MP4 files or a folder to prepare your gallery.</li>
  <li><strong>Preview</strong> &mdash; select a thumbnail to see its image and file details.</li>
  <li><strong>Import Video</strong> &mdash; open that video for playback and clipping.</li>
  <li><strong>Mark</strong> &mdash; place two markers around a moment you want to keep.</li>
  <li><strong>Add Clip</strong> &mdash; queue the selection and keep finding more moments.</li>
  <li><strong>Export Clips</strong> &mdash; export the queue into separate files.</li>
</ol>
<p>Your source footage stays untouched.</p>

<h2>Two ways to export</h2>
<table>
  <thead><tr><th>Mode</th><th>Best for</th><th>How it works</th></tr></thead>
  <tbody>
    <tr><td><strong>Fast &middot; Original Quality</strong></td><td>Quick exports with the original encoded quality</td><td>Copies media without re-encoding into either <code>.mov</code> or <code>.mp4</code> files. Cuts may follow keyframe boundaries rather than your exact markers.</td></tr>
    <tr><td><strong>Precise &middot; Re-Encode</strong></td><td>Cuts that closely follow your selected markers</td><td>Re-encodes selected ranges into <code>.mp4</code> files. Takes longer, and compression can change the image quality and file size.</td></tr>
  </tbody>
</table>
<p>Playback speed changes your preview only. Exported clips retain normal playback speed.</p>
<p>Exports are organized automatically (using .mov as an example):</p>
<pre><code>TrimWasp-Clips-FileName/
  TrimWasp-Clip-1-FileName.mov
  TrimWasp-Clip-2-FileName.mov
  TrimWasp-Clip-3-FileName.mov</code></pre>

<h2>Keyboard shortcuts</h2>
<table>
  <thead><tr><th>Key</th><th>Action</th></tr></thead>
  <tbody>
    <tr><td><kbd>Space</kbd></td><td>Play / Pause</td></tr>
    <tr><td><kbd>&larr;</kbd> / <kbd>&rarr;</kbd></td><td>Previous / Next Frame</td></tr>
    <tr><td><kbd>M</kbd></td><td>Place Marker</td></tr>
    <tr><td><kbd>A</kbd></td><td>Add Clip / Update Clip</td></tr>
  </tbody>
</table>

<h2>Screenshots</h2>
<blockquote><p>Screenshots coming soon.</p></blockquote>

<h2>Choose your platform</h2>
<div style="color: #22c55e;">
  <h3><img src="assets/macos.svg" alt="macOS 13 or newer" height="28"></h3>
  <p><strong>🟢 Built with Swift, AppKit, AVKit, and AVFoundation.</strong> The Mac app uses Apple's built-in media frameworks, with no separate media-tool downloads.</p>
  <p>🟢 Requires <strong>macOS 13 or newer</strong> and Apple's Command Line Tools.</p>
  <p>🟢 Open the Mac project folder and run <strong>Build.command</strong>. The script reads <code>Version.txt</code>, builds the app, adds its icon, and applies a local ad-hoc signature. The result is <code>build/TrimWasp.app</code>.</p>
  <p>🟢 This is a local signature, not Apple notarization; macOS may require an explicit approval before launch.</p>
</div>

<div style="color: #ef4444;">
  <h3><img src="assets/windows.svg" alt="Windows 10 and 11, x64" height="28"></h3>
  <p><strong>🔴 Built with C#, WPF, LibVLCSharp, LibVLC, and FFmpeg / FFprobe.</strong> The Windows version includes additional playback tools and runtime files, so its complete application folder is larger.</p>
  <p>🔴 Requires <strong>Windows 10 or 11, x64</strong>, and <strong>Visual Studio 2022 17.8+</strong> with the <strong>.NET desktop development</strong> workload, or a compatible .NET SDK for command-line builds. The project targets <strong>.NET 8</strong>.</p>
  <p>🔴 Open <strong>TrimWasp.sln</strong> to build in Visual Studio. For a self-contained application folder, run <strong>Build.cmd</strong>. The result is <code>artifacts/TrimWasp/TrimWasp.exe</code>; keep the entire output folder together.</p>
  <p>🔴 First-time setup downloads the playback dependencies and FFmpeg tools. Editing and exporting local footage work offline afterward.</p>
  <p>🔴 Dependency licenses and redistribution information are listed in the Windows project's <code>THIRD-PARTY-NOTICES.md</code>.</p>
</div>

<h2>Local footage stays local</h2>
<p>TrimWasp has no application telemetry, analytics, or media-upload implementation. Thumbnails and clip exports are processed on your computer.</p>
<p>Saved clip-list files include the original video's local path so the app can find it again. Keep those files private if the path contains personal information. Exported videos may retain source metadata; TrimWasp is not a metadata anonymization tool.</p>



<h2>AI disclosure</h2>
<p>TrimWasp was created using AI. This app has been incredibly useful to me, and I wanted to share it with others who might find it useful too.</p>
