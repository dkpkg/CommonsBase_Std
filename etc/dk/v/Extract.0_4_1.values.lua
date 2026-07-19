local M = {
  id = "CommonsBase_Std.Extract@0.4.1"
}

-- lua-ml does not support local functions.
-- And if the variable was "local" it would be nil inside the rules/uirules function bodies.
-- So a should-be-unique global is used instead.
CommonsBase_Std__Extract__0_4_1 = {}

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
    CommonsBase_Std__Extract__0_4_1.common_params(request, p)
    return CommonsBase_Std__Extract__0_4_1.untar(p)
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
    CommonsBase_Std__Extract__0_4_1.common_params(request, p)
    return CommonsBase_Std__Extract__0_4_1.tartozip(p)
  end
end

function CommonsBase_Std__Extract__0_4_1.common_params(request, p)
  local tarmodver = assert(request.user.tarmodver, "please provide `tarmodver=MODULE@VERSION`")
  local tarassetpath = assert(request.user.tarassetpath, "please provide `tarassetpath=ASSETPATH`")
  local gzip = string.find(tarassetpath, "%.tar%.gz$") ~= nil
  local xz = string.find(tarassetpath, "%.tar%.xz$") ~= nil
  local bz2 = string.find(tarassetpath, "%.tar%.bz2$") ~= nil
  local toyboxexe = "$(get-object CommonsBase_Std.Toybox@0.8.9 -s Release.execution_abi -m ./toybox -f toybox.exe -e '*')"
  local sevenzzexe = "$(get-object CommonsBase_Std.S7z@25.1.0 -s Release.execution_abi -e '*' -d :)/7zz.exe"
  local sevenzexe_win32 = "$(get-object CommonsBase_Std.S7z.Windows7zExe@25.1.0 -s Release.execution_abi -d :)/7z.exe"
  local coreutilsexe = "$(get-object CommonsBase_Std.Coreutils@0.6.0 -s Release.execution_abi -m ./coreutils.exe -f coreutils.exe -e '*')"

  -- /a/b/c.tar.gz -> ("z", /a/b/c.tar)
  -- /a/b/c.tar.xz -> ("J", /a/b/c.tar)
  -- /a/b/c.tar.bz2 -> ("j", /a/b/c.tar)
  local tarcompressflag = ""
  local file_tar = ""
  if gzip then
    tarcompressflag = "z"
    file_tar = string.sub(tarassetpath, 1, -4) -- remove .gz
  elseif xz then
    tarcompressflag = "J"
    file_tar = string.sub(tarassetpath, 1, -4) -- remove .xz
  elseif bz2 then
    tarcompressflag = "j"
    file_tar = string.sub(tarassetpath, 1, -5) -- remove .bz2
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
  p.toyboxexe = toyboxexe
  p.sevenzzexe = sevenzzexe
  p.sevenzexe_win32 = sevenzexe_win32
  p.coreutilsexe = coreutilsexe
end

function CommonsBase_Std__Extract__0_4_1.untar(p)
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

function CommonsBase_Std__Extract__0_4_1.tartozip_win32_helper(win32_commands, p, slot)
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

function CommonsBase_Std__Extract__0_4_1.tartozip(p)
  local commands = {
    -- macOS
      -- macOS system tar
      -- with [env -u] so runs on macOS slots only
    {
      p.coreutilsexe, "env", "-u", "${SLOT.Release.Darwin_x86_64}", "--",
      "/usr/bin/tar",
      "-x" .. p.tarcompressflag .. "f",
      p.tarfile
    },
    {
      p.coreutilsexe, "env", "-u", "${SLOT.Release.Darwin_arm64}", "--",
      "/usr/bin/tar",
      "-x" .. p.tarcompressflag .. "f",
      p.tarfile
    },
      -- [p.sevenzzee] is 7zz. Trailing "*" is the source (extracted cwd contents).
    {
      p.sevenzzexe, "a",
      "${SLOT.Release.Darwin_x86_64}/output.zip", "*"
    },
    {
      p.sevenzzexe, "a",
      "${SLOT.Release.Darwin_arm64}/output.zip", "*"
    },

    -- Linux
      -- with [env -u] so runs on macOS slots only
    {
      p.coreutilsexe, "env", "-u", "${SLOT.Release.Linux_x86_64}", "--",
      p.toyboxexe,
      "tar", "-x" .. p.tarcompressflag .. "f", p.tarfile
    },
    {
      p.coreutilsexe, "env", "-u", "${SLOT.Release.Linux_arm64}", "--",
      p.toyboxexe,
      "tar", "-x" .. p.tarcompressflag .. "f", p.tarfile
    },
    {
      p.coreutilsexe, "env", "-u", "${SLOT.Release.Linux_x86}", "--",
      p.toyboxexe,
      "tar", "-x" .. p.tarcompressflag .. "f", p.tarfile
    },
      -- [p.sevenzzee] is 7zz. Trailing "*" is the source (extracted cwd contents).
    {
      p.sevenzzexe, "a",
      "${SLOT.Release.Linux_x86_64}/output.zip", "*"
    },
    {
      p.sevenzzexe, "a",
      "${SLOT.Release.Linux_x86}/output.zip", "*"
    },
    {
      p.sevenzzexe, "a",
      "${SLOT.Release.Linux_arm64}/output.zip", "*"
    },
  }

  if p.gzip or p.xz or p.bz2 then
    CommonsBase_Std__Extract__0_4_1.tartozip_win32_helper(commands, p, "Windows_x86")
    CommonsBase_Std__Extract__0_4_1.tartozip_win32_helper(commands, p, "Windows_x86_64")
    CommonsBase_Std__Extract__0_4_1.tartozip_win32_helper(commands, p, "Windows_arm64")
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
  -- (windows) create output.zip from the extracted tar contents in the cwd.
  -- The trailing "*" is the source: without it `7z a` has no files to add and
  -- produces an empty (non-zipfile) object.
  table.insert(commands, {
    p.sevenzexe_win32, "a", "${SLOT.Release.Windows_x86}/output.zip", "*"
  })
  table.insert(commands, {
    p.sevenzexe_win32, "a", "${SLOT.Release.Windows_x86_64}/output.zip", "*"
  })
  table.insert(commands, {
    p.sevenzexe_win32, "a", "${SLOT.Release.Windows_arm64}/output.zip", "*"
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
