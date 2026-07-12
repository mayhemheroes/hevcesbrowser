#!/usr/bin/env bash
#
# Fetch the HEVC test sample streams that the upstream boost.test suite
# (hevcparser/tests/Parsing.cpp) reads from `<tests-dir>/samples/`. Upstream ships
# only a `get_samples.sh` that downloads them from Dropbox; this mirrors that list
# (with dl=1 direct-download links) into the source tree so the tests can run.
#
# Invoked ONLY from the Dockerfile at image-build time (network available). It is NOT
# part of build.sh, so the air-gapped `docker run --network none ... build.sh` re-run
# never touches the network.
set -euo pipefail

DEST="${SRC:-/mayhem}/hevcparser/tests/samples"
mkdir -p "$DEST"
cd "$DEST"

# name<TAB>dropbox-path (s/<id>/<name>)
fetch() {
  local name="$1" path="$2"
  wget --tries=5 --timeout=60 -q "https://www.dropbox.com/s/${path}?dl=1" -O "$name"
  [ -s "$name" ] || { echo "fetch-test-samples: empty download for $name" >&2; exit 1; }
}

fetch Sintel_272p_logo_30.265                      f7igqdmxi9ba8i7/Sintel_272p_logo_30.265
fetch surfing_30.265                               wjngaehonsgdb8u/surfing_30.265
fetch video-h265.hevc                              ntpugiwrpphbff7/video-h265.hevc
fetch 10E_11345V_4T2_record_part.265               zdwloz1v2b2eh2z/10E_11345V_4T2_record_part.265
fetch TearsOfSteel_720p_h265_part.hevc             4hsd208hnm7o85f/TearsOfSteel_720p_h265_part.hevc
fetch Jellyfish-3-Mbps-1080p-hevc_part.hevc        3jhfgpegt09uy3m/Jellyfish-3-Mbps-1080p-hevc_part.hevc
fetch ffmpeg_default.hevc                          c754v5vnxae3ftm/ffmpeg_default.hevc
fetch ffmpeg_cp_tr_cm_2020.hevc                    y64y7l63yl4m1aq/ffmpeg_cp_tr_cm_2020.hevc
fetch f265_default.hevc                            ghqcmvvv6n78hb4/f265_default.hevc
fetch homer_default.hevc                           xqrj1igvvopdonv/homer_default.hevc
fetch BQSquare_416x240_60_qp37.bin                 o2ushkw4z4sxlln/BQSquare_416x240_60_qp37.bin
fetch TestCase1_LifeOfPie_ReEncoded1080pX265_HDR_part.hevc uoluk07t65k804m/TestCase1_LifeOfPie_ReEncoded1080pX265_HDR_part.hevc
fetch x265_cll.hevc                                uoaaeu9cwi3wqw3/x265_cll.hevc
fetch HM1.bin                                      iktcn1ugmv7wfjs/HM1.bin
fetch HM2.bin                                      g13e4396kp7nf7b/HM2.bin

echo "fetch-test-samples: fetched $(ls -1 | wc -l) samples into $DEST"
