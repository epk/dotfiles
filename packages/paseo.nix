{
  paseo,
  nodejs_24,
  jq,
}:

(paseo.override { nodejs_22 = nodejs_24; }).overrideAttrs (old: {
  npmFlags = (old.npmFlags or [ ]) ++ [ "--legacy-peer-deps" ];
  postPatch = (old.postPatch or "") + ''
    # Keep the locked website dependencies. Remove the conflicting root overrides.
    ${jq}/bin/jq 'del(.overrides.react, .overrides."react-dom")' package.json > package.json.new
    mv package.json.new package.json
  '';
})
