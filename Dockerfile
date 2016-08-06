FROM ubuntu:trusty

RUN apt-get update \
    && apt-get install -y wget
RUN wget -qO- ftp://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/5.3.0-HCP/freesurfer-Linux-centos4_x86_64-stable-pub-v5.3.0-HCP.tar.gz | tar zxv -C /opt
RUN /bin/bash -c 'echo "krzysztof.gorgolewski@gmail.com\n5172\n *CvumvEV3zTfg" > /opt/freesurfer/.license'

RUN apt-get install -y python3
RUN apt-get install -y python3-pip
RUN pip3 install nibabel

RUN apt-get install -y tcsh
RUN apt-get install -y bc
RUN apt-get install -y tar libgomp1 perl-modules

RUN mkdir /opt/qa_tools
RUN wget -qO- "https://surfer.nmr.mgh.harvard.edu/fswiki/QATools?action=AttachFile&do=get&target=QAtools_v1.1.tar" | tar xv -C /opt/qa_tools
RUN apt-get install -y gawk libglu1-mesa imagemagick libxmu6
RUN apt-get install -y xpra xserver-xorg-video-dummy
RUN useradd -m xpra
RUN echo 'xpra:changeme' |chpasswd
RUN chsh -s /bin/bash xpra
ADD http://xpra.org/xorg.conf /home/xpra/xorg.conf
RUN /bin/echo -e "export DISPLAY=:100" > /home/xpra/.profile && chown xpra:xpra /home/xpra/xorg.conf
RUN apt-get install -y supervisor
RUN /bin/echo -e "[program:xpra] \ncommand=xpra --no-daemon --xvfb=\"Xorg -dpi 96 -noreset -nolisten tcp +extension GLX +extension RANDR +extension RENDER -logfile /home/xpra/.xpra/Xvfb-10.log -config /home/xpra/xorg.conf\" start :100 \nuser=xpra \nenvironment=HOME=\"/home/xpra\" \n" > /etc/supervisor/conf.d/xpra.conf

ADD https://github.com/bencawkwell/supervisor-tools/raw/master/wait-for-daemons.sh /wait-for-daemons.sh
RUN chmod +x wait-for-daemons.sh

ENV QA_TOOLS /opt/qa_tools
ENV DISPLAY :100
ENV OS Linux
ENV FS_OVERRIDE 0
ENV FIX_VERTEX_AREA=
ENV SUBJECTS_DIR /opt/freesurfer/subjects
ENV FSF_OUTPUT_FORMAT nii.gz
ENV MNI_DIR /opt/freesurfer/mni
ENV LOCAL_DIR /opt/freesurfer/local
ENV FREESURFER_HOME /opt/freesurfer
ENV FSFAST_HOME /opt/freesurfer/fsfast
ENV MINC_BIN_DIR /opt/freesurfer/mni/bin
ENV MINC_LIB_DIR /opt/freesurfer/mni/lib
ENV MNI_DATAPATH /opt/freesurfer/mni/data
ENV FMRI_ANALYSIS_DIR /opt/freesurfer/fsfast
ENV PERL5LIB /opt/freesurfer/mni/lib/perl5/5.8.5
ENV MNI_PERL5LIB /opt/freesurfer/mni/lib/perl5/5.8.5
ENV PATH /opt/freesurfer/bin:/opt/freesurfer/fsfast/bin:/opt/freesurfer/tktools:/opt/freesurfer/mni/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN mkdir /scratch
RUN mkdir /local-scratch

RUN mkdir -p /code
COPY run.py /code/run.py

RUN /bin/echo -e "#!/bin/bash \n/usr/bin/supervisord \n./wait-for-daemons.sh xpra\n /code/run.py $@" > /start.sh
RUN chmod +x start.sh

ENTRYPOINT ["/start.sh"]
