# RHA Dashboards — Setup & Update Guide

This walks you through everything needed to run, update, and republish the
two dashboards:

- **Asthma Program Impact Dashboard** — maps showing how well the
  state-wide asthma program is working, by Chicago neighborhood, county,
  and legislative district.
- **Youth Vaping Attendance Dashboard** — maps showing youth
  vaping-prevention program attendance by Chicago neighborhood.

You don't need any coding experience. You will be clicking buttons in an
application called RStudio. Anywhere you see `like this`, that's an exact
file name, button label, or thing to type.

The overall pattern, every time you need to publish new data, is always the
same four steps:
1. Drop the new data file into the right folder.
2. Click **Source** on one script to process it.
3. Click **Publish** to send the updated dashboard live.
4. Check the live link to make sure it looks right.

---

## Part 1 — One-time computer setup

You only do this section once, when you're first getting started.

### 1.1 Get access to the code
The code lives in a private GitHub repository. [Your name] needs to add you
as a collaborator first — let them know your GitHub username (or the email
you'd like to sign up with) if you don't already have a GitHub account.

Once you've been added:
1. Go to `https://github.com/mdschlueter/RHA-Dashboards` and log in.
2. Click the green **Code** button → **Download ZIP**.
3. Find the downloaded `RHA-Dashboards-main.zip` file (usually in your
   Downloads folder) and unzip it (double-click on Mac; right-click →
   "Extract All" on Windows).
4. Move the unzipped `RHA-Dashboards-main` folder somewhere permanent, like
   your Documents folder. This is your project folder from now on.

### 1.2 Install R
R is the underlying software the dashboards are built with.
1. Go to `https://cloud.r-project.org`.
2. Click the download link for your operating system (Windows or Mac).
3. Run the installer with the default options.

### 1.3 Install RStudio
RStudio is the application you'll actually work in — think of it as the
control panel for R.
1. Go to `https://posit.co/download/rstudio-desktop/`.
2. Download the free **RStudio Desktop** version for your operating system.
3. Run the installer with the default options.

### 1.4 Open the project
1. Open RStudio.
2. Go to **File → Open Project...**
3. Navigate to your `RHA-Dashboards-main` folder and select
   `Chicago Interactive Maap.Rproj`.
4. RStudio will reopen with this project loaded — you'll see the project
   name in the top-right corner of the window from now on.

### 1.5 Install the required packages
1. In the **Files** pane (bottom-right of RStudio), click on
   `install_packages.R` to open it.
2. Click the **Source** button at the top-right of that file's editor pane
   (or press Cmd+Shift+Enter on Mac / Ctrl+Shift+Enter on Windows).
3. Watch the **Console** pane (bottom-left) — this installs everything and
   can take several minutes the first time. Wait until it stops printing
   and you see the `>` prompt again.

### 1.6 Create and connect a shinyapps.io account
This is the free hosting service that makes the dashboards into real
websites.
1. Go to `https://www.shinyapps.io` and click **Sign Up** (the free plan is
   fine to start).
2. Once logged in, go to your **Account → Tokens** page and click
   **Show** next to your token. Keep this browser tab open.
3. Back in RStudio, open any app file, for example
   `asthma_app/app.R` (click it in the Files pane).
4. Click the blue **Publish** icon (top-right of that editor pane, looks
   like a blue circle with radiating lines).
5. The first time, RStudio will ask you to connect an account — choose
   **ShinyApps.io** and click **Connect**.
6. A dialog appears asking for your **Account name**, **Token**, and
   **Secret** — copy/paste each one from the shinyapps.io tab you kept
   open, using the **Show Secret** button there to reveal the secret.
7. Click **Connect Account**. RStudio now remembers this — you won't need
   to do this step again.
8. You can close the Publish dialog for now without publishing anything
   yet (click Cancel) — Parts 2 and 3 below cover publishing each app.

Setup is done. Everything past this point is the repeatable update process.

---

## Part 2 — Updating & republishing the Asthma Dashboard

Do this whenever you have a new incident/return-rate data export.

### 2.1 Replace the data file
Copy the new export into the `asthma_app` folder, replacing the existing
file. **It must be named exactly:**
```
school_level_linked_incs_251008.csv
```

### 2.2 Reprocess the data
1. In RStudio's Files pane, open `asthma_app/preprocess_data.R`.
2. Click **Run** (top-right of the editor pane).
3. This takes **3–5 minutes** — it's looking up the location of every
   school address and rebuilding the five map files the dashboard uses.
   Watch the Console pane for progress messages.
4. **Check the last few messages carefully.** You should see something
   like:
   ```
   Geocoding success rate: 98.5% (...)
   ```
   - If the success rate is **90% or higher**, you're good — continue to
     2.3.
   - If it stops with an error saying the geocoding success rate is
     **below the 90% safety threshold**, **do not continue to publishing**.
     This means a lot of addresses in the new file couldn't be matched to a
     location (often a formatting problem). Contact Matthew Schlueter before
     going further.

### 2.3 Publish the updated dashboard
1. Open `asthma_app/app.R` in RStudio.
2. Click the blue **Publish** button (top-right of the editor pane).
3. A checklist of files appears. Make sure these are checked:
   - `app.R`
   - `chicago_map_data.rds`
   - `county_map_data.rds`
   - `congress_map_data.rds`
   - `house_map_data.rds`
   - `senate_map_data.rds`
   Leave everything else **unchecked** (the CSV and geojson files don't
   need to be uploaded — the dashboard only needs the processed `.rds`
   files).
4. Click **Publish**. A browser window will open automatically once it's
   done, showing the live, updated dashboard.
5. Double check a couple of neighborhoods/counties to make sure the numbers
   look reasonable before telling anyone the update is live.

---

## Part 3 — Updating & republishing the Vaping Dashboard

Do this whenever you have a new attendance data export.

### 3.1 Replace the data file
Copy the new export into the `vaping_app` folder, replacing the existing
file. **It must be named exactly:**
```
Youth Vaping Data 2022-2026.xlsx
```

### 3.2 Reprocess the data
1. In RStudio's Files pane, open `vaping_app/geocode_attendees.R`.
2. Click **Source** (top-right of the editor pane).
3. This takes **1–2 minutes**. Watch the Console for the same kind of
   geocoding success message as above — again, if it's below 90%, stop and
   contact [your name] rather than publishing.
4. This creates/updates a file called `geocoded_attendees.csv` in the
   `vaping_app` folder.

### 3.3 Publish the updated dashboard
1. Open `vaping_app/app.R` in RStudio.
2. Click the blue **Publish** button.
3. Make sure these files are checked:
   - `app.R`
   - `geocoded_attendees.csv`
   - `Youth Vaping Data 2022-2026.xlsx`
   - `chicago_neighborhoods.geojson`
4. Click **Publish** and confirm the dashboard looks right once it opens.

---

## Part 4 — Getting future code updates

Occasionally Matthew Schlueter may improve the dashboards themselves (new
features, bug fixes) rather than just new data. When that happens:

1. You'll be told there's a code update available.
2. Go back to `https://github.com/mdschlueter/RHA-Dashboards` and download
   the ZIP again (same as step 1.1).
3. **Before you unzip over your old folder**, copy your latest data files
   somewhere safe:
   - `asthma_app/school_level_linked_incs_251008.csv`
   - `vaping_app/Youth Vaping Data 2022-2026.xlsx`
4. Unzip the new version, then copy those two data files back into their
   folders in the new copy.
5. Re-run Parts 2 and 3 above (reprocess + publish) to bring both
   dashboards up to date on the new code with your current data.

---

## Troubleshooting

| What you see | What it means | What to do |
|---|---|---|
| Console shows `there is no package called '...'` | A package didn't install | Re-run `install_packages.R` (Part 1.5), then try again |
| Publish fails with an authorization/account error | RStudio lost the connection to shinyapps.io | Go to **Tools → Global Options → Publishing**, remove the account, then reconnect it (Part 1.6) |
| Geocoding success rate below 90% | Many addresses in the new file weren't recognized | Don't publish. Check the new file for typos in addresses/zip codes, or contact [your name] |
| The Publish button doesn't appear | You don't have an `app.R` file open, or it's a plain script instead of a Shiny app | Make sure you clicked directly on `app.R` in the Files pane |
| Preprocessing script errors out immediately | Usually a missing or renamed data file | Double-check the file name matches exactly, including capitalization |

---

## Who to contact

Matthew Schlueter — matthew.schlueter@u.northwestern.edu — for anything not covered above, or if a
geocoding/data-quality warning stops you partway through.
