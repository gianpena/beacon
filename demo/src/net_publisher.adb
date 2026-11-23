--  Network demo, sending side.
--     net_publisher [group] [port] [count]     defaults 239.255.0.1 5000 200
--  Run net_subscriber in another process with the same group and port.
--  Publishes Count readings at 1 kHz through a Best_Effort egress bridge.
--  Count = 0 means publish forever (use Ctrl-C to stop); any positive count
--  keeps the original finite behaviour.

with Ada.Command_Line;       use Ada.Command_Line;
with Ada.Text_IO;            use Ada.Text_IO;
with Beacon;                 use Beacon;
with Beacon.Bridge;
with Beacon.Transport.UDP;
with GNAT.Sockets;
with Telemetry;              use Telemetry;
with Telemetry.Codecs;       use Telemetry.Codecs;

procedure Net_Publisher is

   package Temperature_Bridge is new Beacon.Bridge
     (Local       => Temperature_Topic,
      Topic_Id    => Temperature_Topic_Id,
      Serialize   => Serialize_Reading,
      Deserialize => Deserialize_Reading);

   Group : constant String := (if Argument_Count >= 1 then Argument (1) else "239.255.0.1");
   Port  : constant GNAT.Sockets.Port_Type :=
     (if Argument_Count >= 2 then GNAT.Sockets.Port_Type'Value (Argument (2)) else 5000);
   Count : constant Natural :=
     (if Argument_Count >= 3 then Natural'Value (Argument (3)) else 200);

   Net : aliased Beacon.Transport.UDP.UDP_Transport;
   Pub : Temperature_Topic.Publisher;

   Seq : Natural := 0;

begin
   Beacon.Transport.UDP.Open (Net, Group, Port);
   Temperature_Bridge.Start_Egress (Net'Access, Best_Effort);
   Temperature_Topic.Create_Publisher (Pub);

   if Count = 0 then
      Put_Line ("net_publisher: " & Group & ":" & Port'Image & ", publishing forever");
   else
      Put_Line ("net_publisher: " & Group & ":" & Port'Image & "," & Count'Image & " readings");
   end if;

   loop
      Seq := Seq + 1;
      Temperature_Topic.Publish
        (Pub, (Sensor => 7, Sequence => Seq, Temperature => Float (Seq) / 10.0));
      delay 0.001;

      if Count /= 0 and then Seq = Count then
         exit;
      end if;

      if Seq mod 1000 = 0 then
         Put_Line ("  published" & Seq'Image & " readings");
      end if;
   end loop;

   delay 0.2;  --  let the egress task flush
   Temperature_Bridge.Stop;
   Beacon.Transport.UDP.Close (Net);
   Put_Line ("net_publisher: done");
end Net_Publisher;
