# pomdate
Pomodoro timer for Playdate

<!-- @import "[TOC]" {cmd="toc" depthFrom=1 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [pomdate](#-pomdate-)
  - [Status](#-status-)
  - [Install](#-install-)
  - [Develop](#-develop-)
  - [Attributions](#-attributions-)

<!-- /code_chunk_output -->


## Status

MVP complete in `main` branch. Useable.
Future work will be asset-related and not greatly effect functionality.

## Install

1. Install [Playdate SDK v1.12.3](https://sdk.play.date/1.12.3/)
2. Clone this repo
3. Compile `app`, ex. from the `pomdate` project root:
```
pdc --main -sdkpath <PATH_TO_SDK> ./app/main.lua ./app/main.pdx
```
4. Open the Playdate Simulator. From `File` > `Open...` open `app/main.pdx`.

The app is now useable in the simulator, if you would like to use it as a desktop app. For running it on the Playdate:

1. Plug your Playdate into your computer and press the lock button twice to unlock it.
2. `Device` > `Upload Game to Device` will install `pomdate` on the Playdate.

### Replace notification sound

1. Create and export your sound according to [playdate specs for sound **samples**](https://sdk.play.date/1.13.1/Inside%20Playdate.html#M-sound).
2. Name your sound 'notif.wav' and place it in 'pomdate/app/assets/sound'
3. Compile and run the app as per the installation instructions above.

Note that some samples may sound significantly different, even *bad*, on the playdate hardware.

## Develop

Class diagram [here](http://www.plantuml.com/plantuml/uml/VLVVRzms37xtNw77hVanO8zP5hJD0Yn0sWwuwmQiA0hPvjbSPCcGgBjSj_pleqNvT6wJl2JIHuhIzucaTQy3QKznCDMectlTWHgDthUQGFrRgSRe45JdzTXZ4yvNeqSng9C0T3km_my_JZEqI3AA8o_Eg6vR6NWOt3Q1ZvMoZcDux7fIRgCaviM5h6FdEO1gj37GAjY2tpE-yNe0vQmQOAZ11rxCQ6TShOqASZA3WNvXTDvFaLCj1bsR4ZbK2coRJb4nA1G_rFz0GzLZbIcUdVrtDOCzjf37l3VrhWrLvV9SerMNbniqS7Kr2NEoMhzPtwpKXRgnSU1v8DwJfmclr1dX03umi9u6dpupr4JlmL82PWElx81MbBKyyT4cF4tS2FOTs9WcmJhtTUAQbwJfjOkMaddKCKY8QCkO7V_WoUp7nDEj6DXCbv9eNLpCsrHgS2rk489ARAgYNvOXug2jxi0ljCXSfn1Cwmu3CTP6hmcT_Gsr2GnF_vCA0xlTsa35TUQyH8NlsqZaBACoc08x2z-xdrWz0Cy2URITC9-s_5ERA5Bar2sPos8KFcUV-FfRi9-laYZLeKmIjqE9oDtnb6_JMSvOOaIguCmwmirUnbyeN_BOdgTX0cTD6DyOfoc16D8DjGpMpXd1XewdtURX7AVQOsp9BnVc-sd7bOisbrzWpdaB0LBHfw7aXmpd7MSVDtvRlINRdYtwHQsBBb9DKba5UYM2FXP98vQUizeXDRqegXl2BGW2d3FPo5apQQA9DEFjsh7bu-sDWG4i2PzhunOAdeJUHTCcU18xsaRzUYNM9_jLuIPyPET5UoYOAzldBiSISZbb3mxs3HDjMtKadVQWGiz_MrNlbJQcB4GRIDi6mgbo8tXDSja11pJQcptlbD92-k1v2PgwAA_QzSXd55mnT1oJHufwwPxdY-wewq2U3rs8oOryOMcTtM0N_J91cLPpBwQixzDvozZ8H2qjxamYe6dPScp8DurV0XYM_7foOJlc9K4kOCwB9wi2mogjXVQ9UsUEDk1K7hSscvVmXqX7U03wgmUxTZTMrwPywzAvP3QbpzeTgk_lMzl2m_DLyrWLiijgEMxBnUVYug0J1oAdS1WzRycU7TPeaFQdRD1Tvw5BTVzJuuRH2Hlb7speSGpiKWFj06m97L8QyhOgz6vdEH-EROssAb-Siw0q-_NWqrwsJKdKOzT3e3C3Mp2pBuR9baAzayQwp3EfUMdbBsIOz2WF8JnvZQDOtZI9vEA-xdGDvaNzPVCaVY4y7orzfVB18gylgJKXWM0yIaVZTdSu81r1SHo_XVYms_GHEc0ds-KqVwckUsqxA7J5d5Xz52eoIS5UeYWadY6uXWUgtKFck76MSi7oSDvkyfdxOy2la8BcXS_5lSDGUiRlpkDNZgVDSSy8esvOocC5TJWK-R8xe1qZSGPivHDwBxTMJE_vDD-RZDwxI4i9JuzaVgSVEDa8B0i-BClv9K65t99uUZoeirVbILI-RotKiUladI0Ffm9TNextdTfvFOxWvVcaJkJfAhkLL2nHc1jOzbXKY76T7BKneFtTF6kztXqcQ4mCv9d9MnTj6uuMtCucT3QKfK_1SHZbQ8L64cC-uGBFxwTbGsiFdefw30h3P5VvGMpsZ6kXVQhgI4e-tuoEtjL1rT2uz9i060fe6r18gjVvdIf-h2VXujNFMePxjAFsUb2TTt6yjJru93r5-Bbw3PQvcVy1)

This project is not yet ready to accept code contributions, but it will be open to them in the future. In the meantime, feel free to [open an issue](https://github.com/sasha-pavlov/pomdate/issues), or send me an email at [src@aspavlov.com]() :)

## Attributions

Notification sound: ['*1 - xylophone.wav*' by 14G_Panska_Niklova_Michaela](https://freesound.org/people/14G_Panska_Niklova_Michaela/sounds/422137/)