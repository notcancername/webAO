import { client } from '../../client'
import { handleCharacterInfo } from '../../client/handleCharacterInfo'
/**
   * Handles incoming character information, bundling multiple characters
   * per packet.
   * CI#0#Phoenix&description&&&&&#1#Miles ...
   * @param {Array} args packet arguments
   */
export const handleCI = (args: string[]) => {
    // Loop through the 10 characters that were sent

    for (let i = 2; i <= args.length - 2; i++) {
        if (i % 2 === 0) {
            document.getElementById(
                "client_loadingtext"
            )!.innerHTML = `Loading Character ${args[1]}/${client.char_list_length}`;
            const chargs = args[i].split("&");
            const charid = Number(args[i - 1]);
            (<HTMLProgressElement>(
                document.getElementById("client_loadingbar")
            )).value = charid;
            setTimeout(() => handleCharacterInfo(chargs, charid), 500);
        }
    }
    // Request the next pack
    client.sender.sendServer(`AN#${Number(args[1]) / 10 + 1}#%`);
}