// =================== COMPARADOR SEMVER RIGUROSO & ÚLTIMA VERSIÓN (DRY D-ADM-01) ===================
/**
 * Comparador SemVer numérico client-side determinista
 */
function compareSemVer(a, b) {
  if (!a && !b) return 0;
  if (!a) return -1;
  if (!b) return 1;

  const parseParts = (s) => {
    const clean = String(s).trim().replace(/^[vV]/, '');
    const withoutSuffix = clean.split('-')[0];
    const buildSplit = withoutSuffix.split('+');
    const segs = buildSplit[0].split('.');
    const major = parseInt(segs[0], 10) || 0;
    const minor = segs.length > 1 ? parseInt(segs[1], 10) || 0 : 0;
    const patch = segs.length > 2 ? parseInt(segs[2], 10) || 0 : 0;
    const build = buildSplit.length > 1 ? parseInt(buildSplit[1], 10) || null : null;
    return { major, minor, patch, build };
  };

  const pa = parseParts(a);
  const pb = parseParts(b);

  if (pa.major !== pb.major) return pa.major - pb.major;
  if (pa.minor !== pb.minor) return pa.minor - pb.minor;
  if (pa.patch !== pb.patch) return pa.patch - pb.patch;
  if (pa.build != null && pb.build != null && pa.build !== pb.build) {
    return pa.build - pb.build;
  }
  return 0;
}

function getLatestPublishedVersion() {
  if (!globalReleases || globalReleases.length === 0) return null;
  let latest = null;
  for (const r of globalReleases) {
    const vn = (r.version_name || '').trim();
    if (vn) {
      if (!latest || compareSemVer(vn, latest) > 0) {
        latest = vn;
      }
    }
  }
  return latest;
}
