local M = {
  id = "CommonsBase_Std.Extract@0.4.2"
}

-- lua-ml does not support local functions.
-- And if the variable was "local" it would be nil inside the rules/uirules function bodies.
-- So a should-be-unique global is used instead.
CommonsBase_Std__Extract__0_4_2 = {}

rules = build.newrules(M)

function rules.F_Untar(command, request)
  if command == "declareoutput" then
    local modver = assert(request.user.modver, "please provide `modver=MODULE@VERSION`")
    local tarmodver = assert(request.user.tarmodver, "please provide `tarmodver=MODULE@VERSION`")
    local tarassetpath = assert(request.user.tarassetpath, "please provide `tarassetpath=ASSETPATH`")
    return {
      declareoutput = {
        return_objects = {
          id = modver,
          slots = {
                    "Release.Windows_x86", "Release.Windows_x86_64", "Release.Windows_arm64",
                    "Release.Darwin_x86_64", "Release.Darwin_arm64",
                    "Release.Linux_x86_64", "Release.Linux_arm64", "Release.Linux_x86"
          },
          execution_slot = "Release.execution_abi"
        }
      }
    }
  elseif command == "declareinput" then
    local tarmodver = assert(request.user.tarmodver, "please provide `tarmodver=MODULE@VERSION`")
    local tarassetpath = assert(request.user.tarassetpath, "please provide `tarassetpath=ASSETPATH`")
    return {
      declareinput = {
        input_assets = {
          { id = tarmodver, path = tarassetpath }
        }
      }
    }
  elseif command == "submit" then
    local paths = assert(request.user.paths, "please provide `'paths[]=PATH1' 'paths[]=PATH2' ...`")
    assert(type(paths) == "table", "paths must be a table. please provide `'paths[]=PATH1' 'paths[]=PATH2' ...`")
    local p = {
      paths = paths
    }
    CommonsBase_Std__Extract__0_4_2.common_params(request, p)
    return CommonsBase_Std__Extract__0_4_2.untar(p)
  end
end

function rules.F_TarToZip(command, request)
  if command == "declareoutput" then
    local modver = assert(request.user.modver, "please provide `modver=MODULE@VERSION`")
    local tarmodver = assert(request.user.tarmodver, "please provide `tarmodver=MODULE@VERSION`")
    local tarassetpath = assert(request.user.tarassetpath, "please provide `tarassetpath=ASSETPATH`")
    return {
      declareoutput = {
        return_objects = {
          id = modver,
          slots = {
            "Release.Windows_x86", "Release.Windows_x86_64", "Release.Windows_arm64",
            "Release.Darwin_x86_64", "Release.Darwin_arm64",
            "Release.Linux_x86_64", "Release.Linux_arm64", "Release.Linux_x86"
          },
          execution_slot = "Release.execution_abi"
        }
      }
    }
  elseif command == "declareinput" then
    local tarmodver = assert(request.user.tarmodver, "please provide `tarmodver=MODULE@VERSION`")
    local tarassetpath = assert(request.user.tarassetpath, "please provide `tarassetpath=ASSETPATH`")
    return {
      declareinput = {
        input_assets = {
          { id = tarmodver, path = tarassetpath }
        }
      }
    }
  elseif command == "submit" then
    local p = {}
    CommonsBase_Std__Extract__0_4_2.common_params(request, p)
    return CommonsBase_Std__Extract__0_4_2.tartozip(p)
  end
end

function CommonsBase_Std__Extract__0_4_2.common_params(request, p)
  local tarmodver = assert(request.user.tarmodver, "please provide `tarmodver=MODULE@VERSION`")
  local tarassetpath = assert(request.user.tarassetpath, "please provide `tarassetpath=ASSETPATH`")
  -- Long suffixes (.tar.gz/.tar.xz/.tar.bz2) and the short tarball
  -- suffixes (.tgz/.txz/.tbz) that GitHub release tarballs commonly use.
  local tgz = string.find(tarassetpath, "%.tgz$") ~= nil
  local txz = string.find(tarassetpath, "%.txz$") ~= nil
  local tbz = string.find(tarassetpath, "%.tbz$") ~= nil
  local zst = string.find(tarassetpath, "%.tar%.zst$") ~= nil
  local gzip = string.find(tarassetpath, "%.tar%.gz$") ~= nil or tgz
  local xz = string.find(tarassetpath, "%.tar%.xz$") ~= nil or txz
  local bz2 = string.find(tarassetpath, "%.tar%.bz2$") ~= nil or tbz
  local toyboxexe = "$(get-object CommonsBase_Std.Toybox@0.8.9 -s Release.execution_abi -m ./toybox -f toybox.exe -e '*')"
  local sevenzzexe = "$(get-object CommonsBase_Std.S7z@25.1.0 -s Release.execution_abi -e '*' -d :)/7zz.exe"
  local sevenzexe_win32 = "$(get-object CommonsBase_Std.S7z.Windows7zExe@25.1.0 -s Release.execution_abi -d :)/7z.exe"
  local coreutilsexe = "$(get-object CommonsBase_Std.Coreutils@0.6.0 -s Release.execution_abi -m ./coreutils.exe -f coreutils.exe -e '*')"

  -- /a/b/c.tar.gz -> ("z", /a/b/c.tar)    /a/b/c.tgz -> ("z", /a/b/c.tar)
  -- /a/b/c.tar.xz -> ("J", /a/b/c.tar)    /a/b/c.txz -> ("J", /a/b/c.tar)
  -- /a/b/c.tar.bz2 -> ("j", /a/b/c.tar)   /a/b/c.tbz -> ("j", /a/b/c.tar)
  -- /a/b/c.tar.zst -> ("", /a/b/c.tar)    (7-Zip decompress; no tar flag)
  -- The short suffixes substitute ".tar" rather than strip: 7-Zip names the
  -- decompressed inner member `c.tar` for `c.tbz` (verified with 7z l), so
  -- file_tar must match that name for the Windows two-step extraction.
  local tarcompressflag = ""
  local file_tar = ""
  if tgz or txz or tbz then
    file_tar = string.sub(tarassetpath, 1, -5) .. ".tar" -- .tgz/.txz/.tbz -> .tar
    if tgz then tarcompressflag = "z"
    elseif txz then tarcompressflag = "J"
    else tarcompressflag = "j" end
  elseif gzip then
    tarcompressflag = "z"
    file_tar = string.sub(tarassetpath, 1, -4) -- remove .gz
  elseif xz then
    tarcompressflag = "J"
    file_tar = string.sub(tarassetpath, 1, -4) -- remove .xz
  elseif bz2 then
    tarcompressflag = "j"
    file_tar = string.sub(tarassetpath, 1, -5) -- remove .bz2
  elseif zst then
    -- Zstandard (e.g. msys2 `.pkg.tar.zst` packages). Neither toybox tar nor
    -- every macOS system tar has a zstd flag, so zst archives are always
    -- decompressed with 7-Zip first (S7z 25.01; zstd needs >= 24.x) and the
    -- resulting plain tar is extracted flagless. 7-Zip names the decompressed
    -- member by stripping `.zst` (c.pkg.tar.zst -> c.pkg.tar; verified with
    -- 7z x on 25.01), matching this file_tar.
    tarcompressflag = ""
    file_tar = string.sub(tarassetpath, 1, -5) -- remove .zst
  else
    file_tar = tarassetpath
  end

  -- file_tar=/a/b/c.tar        -> c.tar
  -- tarassetpath=/a/b/c.tar.gz -> c.tar.gz
  local baseidx = assert(string.find(file_tar, "[^/][^/]*$"), "`" .. tarassetpath .. "` tarball must have a basename")
  local file_tar_basename = string.sub(file_tar, baseidx)
  local file_tarz_filename = string.sub(tarassetpath, baseidx)

  p.outputid = request.submit.outputid
  p.outputmodule = request.submit.outputmodule
  p.outputversion = request.submit.outputversion

  p.tarfile = string.format("$(get-asset %s -p %s -f %s)", tarmodver, tarassetpath, file_tarz_filename)
  p.file_tar = file_tar
  p.file_tar_basename = file_tar_basename
  p.tarcompressflag = tarcompressflag
  p.gzip = gzip
  p.xz = xz
  p.bz2 = bz2
  p.zst = zst
  p.toyboxexe = toyboxexe
  p.sevenzzexe = sevenzzexe
  p.sevenzexe_win32 = sevenzexe_win32
  p.coreutilsexe = coreutilsexe

  -- Optional post-extraction shaping (used by `F_Untar`):
  --   nstrip=N   strip N leading path components (like tar --strip-components)
  --   destdir=D  extract into the "<slot>/D" subdirectory instead of the slot root
  -- Defaults (0 / nil) preserve the original @0.2.0 behavior.
  p.nstrip = tonumber(request.user.nstrip or "0") or 0
  p.destdir = request.user.destdir
end

-- Append each of `paths` (a Lua array) as trailing arguments to the command
-- array `cmd`, then return `cmd`. Used to restrict extraction to the requested
-- members (rather than extracting the whole archive as in @0.1.0).
function CommonsBase_Std__Extract__0_4_2.append_paths(cmd, paths)
  local i = 1
  while paths[i] ~= nil do
    table.insert(cmd, paths[i])
    i = i + 1
  end
  return cmd
end

-- Strip `nstrip` leading `component/` segments from `path`. Mirrors tar
-- `--strip-components=<nstrip>` so the declared outputs match what is extracted.
-- (lua-ml: module-level function, since local functions are unsupported.)
function CommonsBase_Std__Extract__0_4_2.strip_leading(path, nstrip)
  local p = path
  local n = nstrip or 0
  local more = 1
  while n > 0 and more == 1 do
    local s, e = string.find(p, "^[^/][^/]*/")
    if s then
      p = string.sub(p, e + 1)
      n = n - 1
    else
      more = 0
    end
  end
  return p
end

-- Directory portion of a forward-slash path ("a/b/c" -> "a/b", "x" -> "").
function CommonsBase_Std__Extract__0_4_2.dirname(path)
  local last = 0
  local i = 1
  local n = string.len(path)
  while i <= n do
    if string.sub(path, i, i) == "/" then last = i end
    i = i + 1
  end
  if last == 0 then return "" end
  return string.sub(path, 1, last - 1)
end

-- Windows shaping (nstrip and/or destdir) without flattening: 7z has no
-- --strip-components, and `7z e` collapses every member to its basename, which
-- mismatches the declared strip_leading outputs whenever a stripped path keeps
-- sub-directories. Instead extract preserving member paths into <slot>, then
-- move each member to its stripped (+ destdir) output path under <slot>.
function CommonsBase_Std__Extract__0_4_2.shape_extract(commands, p, slot, archive, nstrip, has_dest)
  local H = CommonsBase_Std__Extract__0_4_2
  table.insert(commands, H.append_paths({ p.sevenzexe_win32, "x", "-o" .. slot, archive }, p.paths))
  local pi = 1
  while p.paths[pi] ~= nil do
    local outrel = H.strip_leading(p.paths[pi], nstrip)
    if has_dest then outrel = p.destdir .. "/" .. outrel end
    local reldir = H.dirname(outrel)
    if reldir ~= "" then
      table.insert(commands, { p.coreutilsexe, "mkdir", "-p", slot .. "/" .. reldir })
    end
    table.insert(commands, { p.coreutilsexe, "mv", slot .. "/" .. p.paths[pi], slot .. "/" .. outrel })
    pi = pi + 1
  end
end

function CommonsBase_Std__Extract__0_4_2.untar(p)
  local commands = {
    -- macOS system tar
    {
      "/usr/bin/tar", "-x" .. p.tarcompressflag .. "f",
      p.tarfile,
      "-C", "${SLOT.Release.Darwin_arm64}" },
    {
      "/usr/bin/tar", "-x" .. p.tarcompressflag .. "f",
      p.tarfile,
      "-C", "${SLOT.Release.Darwin_x86_64}" },
    -- toybox for Linux
    {
      p.toyboxexe, "tar", "-x" .. p.tarcompressflag .. "f",
      p.tarfile,
      "-C", "${SLOT.Release.Linux_arm64}" },
    {
      p.toyboxexe, "tar", "-x" .. p.tarcompressflag .. "f",
      p.tarfile,
      "-C", "${SLOT.Release.Linux_x86_64}" },
    {
      p.toyboxexe, "tar", "-x" .. p.tarcompressflag .. "f",
      p.tarfile,
      "-C", "${SLOT.Release.Linux_x86}" },
  }
  if p.gzip or p.xz or p.bz2 then
        -- extract the .tar.gz/.tar.xz/.tar.bz2 to a .tar
          -- with [env -u] so runs on Windows slots only
          -- with [7z.exe] ...
          -- uncompress
          -- to current directory
          -- the .tar.gz
          -- select the .tar extracted output
    table.insert(commands, {
        p.coreutilsexe, "env", "-u", "${SLOT.Release.Windows_x86}", "--",
        p.sevenzexe_win32, "x",
        "-o.", p.tarfile, p.file_tar_basename
      })
    table.insert(commands, {
        p.coreutilsexe, "env", "-u", "first", "-u", "${SLOT.Release.Windows_x86_64}", "--",
        p.sevenzexe_win32, "x",
        "-o.", p.tarfile, p.file_tar_basename
      })
    table.insert(commands, {
        p.coreutilsexe, "env", "-u", "${SLOT.Release.Windows_arm64}", "--",
        p.sevenzexe_win32, "x",
        "-o.", p.tarfile, p.file_tar_basename
      })
        -- extract the .tar
          -- with [7z.exe] ...
          -- uncompress
          -- to output directory
          -- the tarball
    table.insert(commands, {
        p.sevenzexe_win32, "x",
        "-o${SLOT.Release.Windows_x86}",
        p.file_tar_basename
      })
    table.insert(commands, {
        p.sevenzexe_win32, "x",
        "-o${SLOT.Release.Windows_x86_64}",
        p.file_tar_basename
      })
    table.insert(commands, {
        p.sevenzexe_win32, "x",
        "-o${SLOT.Release.Windows_arm64}",
        p.file_tar_basename
      })
  else
        -- with [7z.exe] ...
        -- uncompress
        -- to output directory
        -- the tarball
    table.insert(commands, {
        p.sevenzexe_win32, "x", "-o${SLOT.Release.Windows_x86}",
        p.tarfile})
    table.insert(commands, {
        p.sevenzexe_win32, "x", "-o${SLOT.Release.Windows_x86_64}",
        p.tarfile})
    table.insert(commands, {
        p.sevenzexe_win32, "x", "-o${SLOT.Release.Windows_arm64}",
        p.tarfile})
  end
  return {
    submit = {
      values = {
        schema_version = { major = 1, minor = 0 },
        forms = {
          {
            id = p.outputid,
            function_ = {
              commands = commands
            },
            outputs = {
              assets = {
                {
                  slots = {
                    "Release.Windows_x86", "Release.Windows_x86_64", "Release.Windows_arm64",
                    "Release.Darwin_x86_64", "Release.Darwin_arm64",
                    "Release.Linux_x86_64", "Release.Linux_arm64", "Release.Linux_x86"
                  },
                  paths = p.paths
                }
              }
            }
          }
        }
      }
    }
  }
end

function CommonsBase_Std__Extract__0_4_2.tartozip_win32_helper(win32_commands, p, slot)
  table.insert(win32_commands,
    {
      p.coreutilsexe, "env", "-u", "${SLOT.Release." .. slot .. "}", "--",
      -- with [7z.exe] ...
      p.sevenzexe_win32,
      -- uncompress
      "x",
      -- to current directory
      "-o.",
      -- the .tar.gz
      p.tarfile,
      -- select the .tar extracted output
      p.file_tar_basename
    })
    -- make temp directory
  table.insert(win32_commands, {
      p.coreutilsexe, "env", "-u", "${SLOT.Release." .. slot .. "}", "--",
      p.coreutilsexe,
      "mkdir",
      "${CACHE}"
    })
    -- move the .tar to a temp directory
  table.insert(win32_commands,{
      p.coreutilsexe, "env", "-u", "${SLOT.Release." .. slot .. "}", "--",
      p.coreutilsexe,
      "mv",
      p.file_tar_basename,
      "${CACHE}/" .. p.file_tar_basename
    })
    -- extract the .tar
  table.insert(win32_commands, {
      p.coreutilsexe, "env", "-u", "${SLOT.Release." .. slot .. "}", "--",
      -- with [7z.exe] ...
      p.sevenzexe_win32,
      -- uncompress
      "x",
      -- to current directory
      "-o.",
      -- the tarball
      "${CACHE}/" .. p.file_tar_basename
    })
    -- remove the .tar from the temp directory
    table.insert(win32_commands, {
      p.coreutilsexe, "env", "-u", "${SLOT.Release." .. slot .. "}", "--",
      p.coreutilsexe,
      "rm",
      "${CACHE}/" .. p.file_tar_basename
    })
end

function CommonsBase_Std__Extract__0_4_2.tartozip(p)
  -- macOS system tar + Linux toybox tar extract into the function working
  -- directory, then 7zz zips it into that slot's output.zip. For zst the
  -- tarball is decompressed with 7zz first (see common_params); toybox tar
  -- has no zstd support. Each command is pinned to its slot with the
  -- [env -u ${SLOT...}] trick so it runs only when that slot is requested.
  local commands = {}
  local unix = {
    { "systar", "${SLOT.Release.Darwin_x86_64}" },
    { "systar", "${SLOT.Release.Darwin_arm64}" },
    { "toybox", "${SLOT.Release.Linux_x86_64}" },
    { "toybox", "${SLOT.Release.Linux_arm64}" },
    { "toybox", "${SLOT.Release.Linux_x86}" },
  }
  local ui = 1
  while unix[ui] ~= nil do
    local slot = unix[ui][2]
    local tarfile = p.tarfile
    if p.zst then
      table.insert(commands, {
        p.coreutilsexe, "env", "-u", slot, "--",
        p.sevenzzexe, "x", "-y", "-o.", p.tarfile, p.file_tar_basename })
      tarfile = p.file_tar_basename
    end
    if unix[ui][1] == "toybox" then
      table.insert(commands, {
        p.coreutilsexe, "env", "-u", slot, "--",
        p.toyboxexe, "tar", "-x" .. p.tarcompressflag .. "f", tarfile })
    else
      table.insert(commands, {
        p.coreutilsexe, "env", "-u", slot, "--",
        "/usr/bin/tar", "-x" .. p.tarcompressflag .. "f", tarfile })
    end
    table.insert(commands, { p.sevenzzexe, "a", slot .. "/output.zip" })
    ui = ui + 1
  end

  if p.gzip or p.xz or p.bz2 or p.zst then
    CommonsBase_Std__Extract__0_4_2.tartozip_win32_helper(commands, p, "Windows_x86")
    CommonsBase_Std__Extract__0_4_2.tartozip_win32_helper(commands, p, "Windows_x86_64")
    CommonsBase_Std__Extract__0_4_2.tartozip_win32_helper(commands, p, "Windows_arm64")
  else
      -- extract the .tar
        -- with [env -u] so runs on Windows slots only
        -- with [7z.exe] ...
        -- uncompress
        -- to current directory
        -- the tarball
    table.insert(commands, {
        p.coreutilsexe, "env", "-u", "${SLOT.Release.Windows_x86}", "--",
        p.sevenzexe_win32, "x", "-o.", p.tarfile
      })
    table.insert(commands, {
        p.coreutilsexe, "env", "-u", "${SLOT.Release.Windows_x86_64}", "--",
        p.sevenzexe_win32, "x", "-o.", p.tarfile
      })
    table.insert(commands, {
        p.coreutilsexe, "env", "-u", "${SLOT.Release.Windows_arm64}", "--",
        p.sevenzexe_win32, "x", "-o.", p.tarfile
      })
  end
  -- (windows) create output.zip from the .tar
  table.insert(commands, {
    p.sevenzexe_win32, "a", "${SLOT.Release.Windows_x86}/output.zip"
  })
  table.insert(commands, {
    p.sevenzexe_win32, "a", "${SLOT.Release.Windows_x86_64}/output.zip"
  })
  table.insert(commands, {
    p.sevenzexe_win32, "a", "${SLOT.Release.Windows_arm64}/output.zip"
  })

  return {
    submit = {
      values = {
        schema_version = { major = 1, minor = 0 },
        forms = {
          {
            id = p.outputid,
            function_ = {
              commands = commands
            },
            outputs = {
              assets = {
                {
                  slots = {
                    "Release.Windows_x86", "Release.Windows_x86_64", "Release.Windows_arm64",
                    "Release.Darwin_x86_64", "Release.Darwin_arm64",
                    "Release.Linux_x86_64", "Release.Linux_arm64", "Release.Linux_x86"
                  },
                  paths = { "output.zip" }
                }
              }
            }
          }
        }
      }
    }
  }
end

return M
