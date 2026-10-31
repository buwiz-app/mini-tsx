// Hello's home screen: greets the friend in buwiz.props.ticket, and shows
// where it is mounted. An app imports only nsh, nsh/base and buwiz; its data
// comes from buwiz.call alone (no fetch, no network).
import { signal, Text, View } from "nsh";
import { buwiz } from "buwiz";

export default function Home() {
  const greeting = signal("Saying hi…");
  const ticket = buwiz.props.ticket;

  // buwiz.call is there because the manifest grants hello_greet
  buwiz.call?.("hello_greet", typeof ticket === "string" ? { ticket } : {}).then(
    (r) => greeting.set(String(r.greeting)),
    (e) => greeting.set(`Could not say hi (${e.code})`),
  );

  // the Bot renders the app in its own theme: every color has its dark:
  // variant, so the app follows the Bot's light or dark setting
  return (
    <View class="flex-1 gap-2 p-4 bg-white dark:bg-[#161616]">
      <Text class="text-[14px] text-[#1c1c1c] dark:text-[#f5f5f5]">{greeting()}</Text>
      <Text class="text-[12px] text-[#1c1c1c99] dark:text-[#f5f5f599]">{`${buwiz.viewport().placement}: ${buwiz.viewport().width}×${buwiz.viewport().height}`}</Text>
    </View>
  );
}
