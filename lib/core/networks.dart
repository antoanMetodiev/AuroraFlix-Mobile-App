/// The networks /series can be filtered by — port of my-app/lib/networks.ts:
/// the ten with the most series in the catalog, with their TMDB network id
/// and logo. [name] is the exact TMDB network name the series service
/// matches on (?network=). TBS, MBS, TOKYO MX and TV Tokyo are the Japanese
/// ones (anime) — that's what the catalog has.
class TopNetwork {
  const TopNetwork(this.name, this.tmdbId, this.logo);

  final String name;
  final int tmdbId;
  final String logo;
}

const topNetworks = [
  TopNetwork('Netflix', 213, '/wwemzKWzjKYJFfCeiB57q3r4Bcm.png'),
  TopNetwork('Prime Video', 1024, '/w7HfLNm9CWwRmAMU58udl2L7We7.png'),
  TopNetwork('HBO', 49, '/tuomPhY2UtuPTqqFnKMVHvSb724.png'),
  TopNetwork('Apple TV', 2552, '/bngHRFi794mnMq34gfVcm9nDxN1.png'),
  TopNetwork('Hulu', 453, '/pqUTCleNUiTLAVlelGxUgWn1ELh.png'),
  TopNetwork('The CW', 71, '/hEpcdJ4O6eitG9ADSnDXNUrlovS.png'),
  TopNetwork('TOKYO MX', 614, '/hSdroyVthq3CynxTIIY7lnS8w1.png'),
  TopNetwork('TBS', 160, '/lUACMATs6jcscXIrzNCQzbvNVN5.png'),
  TopNetwork('MBS', 94, '/7RNXnyiMbjgqtPAjja13wchcrGI.png'),
  TopNetwork('TV Tokyo', 98, '/jnuO8pZNEBLEq5YaOP1f5OkmG91.png'),
];

bool isTopNetwork(String? name) => name != null && topNetworks.any((n) => n.name == name);
