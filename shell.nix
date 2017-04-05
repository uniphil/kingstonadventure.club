with import <nixpkgs> {};
with pkgs.python27Packages;

# docker run -it --net=host -e POSTGRES_DB=tendenci mdillon/postgis

(
  let

    # new pillow requires olefile, which is not in nixpkgs
    olefile = pkgs.python27Packages.buildPythonPackage rec {
      name = "olefile";
      version = "0.44";
      src = pkgs.fetchurl {
        url = "https://pypi.python.org/packages/35/17/c15d41d5a8f8b98cc3df25eb00c5cee76193114c78e5674df6ef4ac92647/olefile-0.44.zip";
        sha256 = "61f2ca0cd0aa77279eb943c07f607438edf374096b66332fae1ee64a6f0f73ad";
      };
    };

    # the nixpkgs pillow is too old for tendenci
    pillow = pkgs.python27Packages.buildPythonPackage rec {
      name = "Pillow-${version}";
      version = "4.0.0";

      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/source/P/Pillow/${name}.tar.gz";
        sha256 = "ee26d2d7e7e300f76ba7b796014c04011394d0c4a5ed9a288264a3e443abca50";
      };

      # Check is disabled because of assertion errors, see
      # https://github.com/python-pillow/Pillow/issues/1259
      doCheck = false;

      buildInputs = with pkgs; [
        pkgs.freetype pkgs.libjpeg pkgs.zlib pkgs.libtiff pkgs.libwebp pkgs.tcl
        python27Packages.nose pkgs.lcms2 pkgs.tk pkgs.xorg.libX11 olefile ];

      # NOTE: we use LCMS_ROOT as WEBP root since there is not other setting for webp.
      preConfigure = let
        libinclude' = pkg: ''"${pkg.out}/lib", "${pkg.out}/include"'';
        libinclude = pkg: ''"${pkg.out}/lib", "${pkg.dev}/include"'';
      in ''
        sed -i "setup.py" \
            -e 's|^FREETYPE_ROOT =.*$|FREETYPE_ROOT = ${libinclude pkgs.freetype}|g ;
                s|^JPEG_ROOT =.*$|JPEG_ROOT = ${libinclude pkgs.libjpeg}|g ;
                s|^ZLIB_ROOT =.*$|ZLIB_ROOT = ${libinclude pkgs.zlib}|g ;
                s|^LCMS_ROOT =.*$|LCMS_ROOT = ${libinclude' pkgs.libwebp}|g ;
                s|^TIFF_ROOT =.*$|TIFF_ROOT = ${libinclude pkgs.libtiff}|g ;
                s|^TCL_ROOT=.*$|TCL_ROOT = ${libinclude' pkgs.tcl}|g ;'
      ''
      # Remove impurities
      + stdenv.lib.optionalString stdenv.isDarwin ''
        substituteInPlace setup.py \
          --replace '"/Library/Frameworks",' "" \
          --replace '"/System/Library/Frameworks"' ""
      '';

      meta = {
        homepage = "https://python-pillow.github.io/";
        description = "Fork of The Python Imaging Library (PIL)";
        longDescription = ''
          The Python Imaging Library (PIL) adds image processing
          capabilities to your Python interpreter.  This library
          supports many file formats, and provides powerful image
          processing and graphics capabilities.
        '';
        license = "http://www.pythonware.com/products/pil/license.htm";
        maintainers = with maintainers; [ goibhniu prikhi ];
      };
    };

  in
    stdenv.mkDerivation {
      name = "tendenciEnv";

      buildInputs = [
        # python basics
        python27Full
        virtualenv
        pip

        # annoying python libs and deps
        geos
        gdal
        python27Packages.python_magic
        pillow
        psycopg2

        # handy dev tools
        git
        docker  # for heroku
        # heroku  # kinda broken in nixpkgs
        foreman
      ];

      src = null;

      LD_LIBRARY_PATH="${geos}/lib:${gdal}/lib:${python_magic}/lib";

      shellHook = ''
        SOURCE_DATE_EPOCH=$(date +%s)  # so that we can use python wheels
        YELLOW='\033[1;33m'
        GREEN='\033[1;32m'
        NC="$(printf '\033[0m')"

        echo -e "''${YELLOW}Creating python environment...''${NC}"
        virtualenv --no-setuptools venv > /dev/null
        export PATH=$PWD/venv/bin:$PATH > /dev/null
        pip install -r requirements.txt > /dev/null
        pip install -r outdoor_adventures/requirements/dev.txt > /dev/null

        heroku() {
          docker run -it --rm -u $(id -u):$(id -g) -w $HOME \
            -v /etc/passwd:/etc/passwd:ro \
            -v /etc/group:/etc/group:ro \
            -v /etc/localtime:/etc/localtime:ro \
            -v /home:/home \
            -v /tmp:/tmp \
            -v /run/user/$(id -u):/run/user/$(id -u) \
            --name heroku \
            johnnagro/heroku-toolbelt "$@"
        }
        export PS1="$GREEN[adventure club]$ $NC"
      '';
    }
)
