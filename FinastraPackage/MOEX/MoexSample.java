Примеры любезно предоставлены Владиславом Бабиным

Пример подписки на поток с использованием openfast \ Short example of use openfast library

public static void main(String[] args) throws IOException {
    InputStream templateSource = new FileInputStream("FIX50SP2-2015-Apr.xml");
    MessageTemplateLoader templateLoader = new XMLMessageTemplateLoader();
    MessageTemplate[] templates = templateLoader.load(templateSource);
    final Context context = new Context();
    Arrays.asList(templates).stream().forEach((t) -> {
        context.registerTemplate(Integer.parseInt(t.getId()), t);
    });


    int port = Integer.parseInt(args[0]);


    NetworkInterface networkInterface = NetworkInterface.getByName("ppp0");
    try (DatagramChannel dc = DatagramChannel.open(StandardProtocolFamily.INET)
            .setOption(StandardSocketOptions.SO_REUSEADDR, true)
            .bind(new InetSocketAddress(port))
            .setOption(StandardSocketOptions.IP_MULTICAST_IF, networkInterface)) {
        InetAddress group = InetAddress.getByName(args[1]);
        InetAddress source = InetAddress.getByName(args[2]);
        MembershipKey key = dc.join(group, networkInterface, source);


        Thread t = new Thread(() -> {
            while (true) {
                try {
                    while (true) {
                        ByteBuffer buf = ByteBuffer.allocate(4096);
                        dc.receive(buf);
                        //System.out.println(String.format("%d bytes received", buf.position()));
                        buf.position(4);
                        ByteBufferBackedInputStream in = new ByteBufferBackedInputStream(buf);
                        FastDecoder decoder = new FastDecoder(context, in);
                        Message message = decoder.readMessage();
                        if (message != null) {
                            System.out.println(String.format("Message template %s %s", message.getTemplate().getId(), message.getTemplate().getName()));
                        } else {
                            System.out.println("Null message, exiting...");
                            break;
                        }
                    }
                } catch (IOException ex) {
                    ex.printStackTrace();
                    break;
                }
            }
        });
        t.start();


        while (t.isAlive()) {
            try {
                Thread.sleep(10);
            } catch(InterruptedException ignore) {
                t.interrupt();
            }
        }


        key.drop();
    }
    System.exit(0);
}

Пример подписки на поток на Java \ Short example on Java

   int port = Integer.parseInt(args[0]);


    NetworkInterface networkInterface = NetworkInterface.getByName("ppp0");
    try (DatagramChannel dc = DatagramChannel.open(StandardProtocolFamily.INET)
            .setOption(StandardSocketOptions.SO_REUSEADDR, true)
            .bind(new InetSocketAddress(port))
            .setOption(StandardSocketOptions.IP_MULTICAST_IF, networkInterface))
    {
        InetAddress group = InetAddress.getByName(args[1]);
        InetAddress source = InetAddress.getByName(args[2]);
        MembershipKey key = dc.join(group, networkInterface, source);


        Thread t = new Thread(()->{
            final ByteBuffer buf = ByteBuffer.allocateDirect(16384);
            while (true) {
                try {
                    while(true) {
                        dc.receive(buf);
                        System.out.println(String.format("%d bytes received", buf.position()));
                        buf.clear();
                    }
                } catch(IOException ex) {
                    ex.printStackTrace();
                    break;
                }
            }
        });
        t.start();
        try {
            while (t.isAlive()) {
                Thread.sleep(100);
            }
        } catch(InterruptedException ex) {
            t.interrupt();
        }
        key.drop();
    }
    System.exit(0);