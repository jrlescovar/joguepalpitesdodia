/** Separated star panels follow the supplied ball silhouette, including its curved edges. */
export default function ChampionsBallIcon({size=18}:{size?:number}) {
  return <svg className="champions-ball-icon" width={size} height={size} viewBox="174 175 205 205" fill="currentColor" aria-hidden="true" focusable="false">
    <path d="m228 272 27-13 4-33 17 25 36-11-21 31 25 29-38-11-17 29-7-35Z"/>
    <path d="m236 187 24-1q17-6 36-6l-16 9 21 9-31 3-11 23-13-18-24 8 19-17Z"/>
    <path d="m306 198 28 9 3-10q21 18 33 45l-15-6 4 28-17-27-30 4 17-21Z"/>
    <path d="m359 269 3 25 13-9q-3 18-14 31l-5 18-8-6-28 11 16-21-20-19 30-1Z"/>
    <path d="m324 340-3 17 22-8q-25 24-65 25l14-8-28-12 40 5Z"/>
    <path d="m208 313 30 22 23-19-5 31 24 12-24-1 4 15q-15-3-23-14-18-2-31-16l20-1Z"/>
    <path d="m199 255 2 19 25-3-21 20 8 27-15-13-10 17-3-27-6-12 13-8Z"/>
    <path d="m215 200-9 16 18-5-21 19-5 25-6-13-12 15q5-30 35-57Z"/>
  </svg>;
}
